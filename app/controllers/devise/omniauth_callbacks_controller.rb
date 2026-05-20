# frozen_string_literal: true

class Devise::OmniauthCallbacksController < DeviseController
  include Devise::Mixins::OmniauthCallback
end
