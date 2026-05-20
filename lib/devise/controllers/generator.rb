module Devise
  module Controllers
    # Generates per-scope Devise controllers at boot for each scope in
    # `Devise.controller_scopes` (configured per application).
    #
    # For a scope `:my_scope`, this creates the constants
    #   MyScope::Devise::BaseController     < MyScope::ApplicationController
    #   MyScope::Devise::SessionsController < MyScope::Devise::BaseController
    #   ... (and Passwords/Registrations/Confirmations/Unlocks/OmniauthCallbacks)
    #
    # Devise behavior is injected by including the corresponding `Devise::Mixins::*`
    # module into each generated class. The mixin pattern exists because Ruby has
    # single inheritance: each generated controller must inherit from the host
    # engine's `ApplicationController` (so it picks up the engine's layout, helpers,
    # before_actions, etc.), so Devise's per-controller logic cannot also live in
    # the parent class — it has to be a module.
    #
    # IMPORTANT — lexical constant resolution:
    # Engine controllers in the host app write
    #   module MyScope
    #     class SessionsController < Devise::SessionsController
    #       ...
    #     end
    #   end
    # Ruby's lexical lookup finds `Devise` in the enclosing `MyScope` module
    # first, so the bare reference `Devise::SessionsController` resolves to
    # `MyScope::Devise::SessionsController` (this generator's output), NOT
    # to the gem's top-level `Devise::SessionsController`. That is what makes the
    # engine controller inherit from the engine's `ApplicationController` chain.
    #
    # Do not "simplify" by dropping the mixin pattern or this generator — the
    # engine controllers depend on the lexical-resolution trick to inherit from
    # `<Scope>::ApplicationController` instead of the gem's `DeviseController`.
    class Generator

      AVAILABLE_CONTROLLERS = [:confirmation, :omniauth_callback, :password, :registration, :session, :unlock]

      attr_reader :scope, :controllers

      def initialize(scope = :devise, *controllers)
        @scope       = scope.to_sym
        @parent      = parent_controller
        @controllers = only_available(controllers)
      end

      def generate
        base_controller
        controllers.each do |controller|
          devise_module_controller(controller)
        end
      end

      class << self
        def generate(scope = :devise, *controllers)
          new(scope, *controllers).generate
        end
      end

      private

      def only_available(args)
        return AVAILABLE_CONTROLLERS if args.blank? or args == [:all]
        AVAILABLE_CONTROLLERS & Array(args)
      end

      def base_controller_name
        if scope == :devise
          "Devise::BaseController"
        else
          "#{scope.to_s.classify}::Devise::BaseController"
        end
      end

      def parent_controller
        if scope == :devise
          Devise.parent_controller.to_s
        else
          "#{scope.to_s.classify}::ApplicationController"
        end.constantize
      end

      def controller_name(option)
        "#{option.to_s.classify.pluralize}Controller"
      end

      def root_module
        scope.to_s.classify.constantize
      rescue StandardError
        Object.const_set(scope.to_s.classify, Module.new)
      end

      def scoped_module
        (scope == :devise) ? root_module : "#{root_module}::Devise".constantize
      rescue StandardError
        root_module.const_set(:Devise, Module.new)
      end

      def set_devise_router
        # The default :devise scope's routes live in the host app's main router,
        # so Devise.router_name must stay nil (→ Devise.available_router_name == :main_app).
        # Setting it to :devise would route URL helpers through `view.devise`, which
        # only exists if something is literally `mount`ed `as: :devise`.
        return if scope == :devise

        @parent.class_variable_set('@@devise_controller_scope', scope)
        @parent.class_eval do
          before_action ->{ Devise.router_name = self.class.class_variable_get('@@devise_controller_scope') }
        end
      end

      def base_controller
        set_devise_router
        klass = find_or_create_class(:BaseController)
        klass.send(:include, Devise::Mixins::Base)
      end

      def devise_module_controller(controller)
        name = controller_name(controller).to_sym
        mixin = Devise::Mixins.const_get(controller.to_s.classify)
        klass = find_or_create_class(name, base_controller_name)
        klass.send(:include, mixin)
      end

      def find_or_create_class(name, parent_name = nil)
        parent = (parent_name || @parent).to_s.constantize

        if scoped_module.constants.include?(name)
          scoped_module.const_get(name)
        else
          scoped_module.const_set(name, Class.new(parent))
        end
      end
    end
  end
end
