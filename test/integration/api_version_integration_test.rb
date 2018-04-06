require_relative '../test_helper'

class ApiVersionIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    super
    Rails.application.routes.draw do
      namespace :api, defaults: { format: 'json' } do
        scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
          match '/test' => 'test#test', via: [:get, :post]
          get 'version', to: 'base_api#version'
          post 'log', to: 'base_api#log'
        end
      end
    end
  end

  test "should recognize route" do
    assert_recognizes({ controller: 'api/v1/test', action: 'test', format: 'json' }, { path: 'api/test', method: :get })
  end

  test "should get version" do
    assert_recognizes({ controller: 'api/v1/base_api', action: 'version', format: 'json' }, { path: 'api/version', method: :get })
  end

  test "should post log" do
    assert_recognizes({ controller: 'api/v1/base_api', action: 'log', format: 'json' }, { path: 'api/log', method: :post })
  end
end
