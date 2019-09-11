module Devise
  module Controllers
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
          @parent.class_variable_set('@@devise_controller_scope', scope)
          @parent.class_eval do
            before_filter ->{ Devise.router_name = self.class.class_variable_get('@@devise_controller_scope') }
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
