require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class ProjectMediasControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::ProjectMediasController.new
    @request.env["devise.mapping"] = Devise.mappings[:api_user]
    sign_out('user')
    User.current = nil
    ProjectMedia.delete_all
    create_annotation_type_and_fields('Embed Code', { 'Copied' => ['Boolean', false] })
  end

  test "should not get oembed of absent media" do
    pm = create_project_media
    get :oembed, id: pm.id + 1
    assert_response 404
  end

  test "should get oembed of private media" do
    t = create_team private: true
    p = create_project team: t
    pm = create_project_media project: p
    get :oembed, id: pm.id
    assert_response :success
  end

  test "should get oembed of existing media" do
    pm = create_project_media
    get :oembed, id: pm.id
    assert_response :success
  end

  test "should allow iframe" do
    pm = create_project_media
    get :oembed, id: pm.id
    assert !@response.headers.include?('X-Frame-Options')
  end

  test "should not embed if app is not Check" do
    stub_config('app_name', 'Bridge') do
      pm = create_project_media
      get :oembed, id: pm.id
      assert_response 501
    end
  end

  test "should create annotation when embedded for the first time only" do
    pm = create_project_media
    assert_equal 0, pm.get_annotations('embed_code').count
    get :oembed, id: pm.id, format: :json
    assert_equal 1, pm.reload.get_annotations('embed_code').count
    get :oembed, id: pm.id, format: :json
    assert_equal 1, pm.reload.get_annotations('embed_code').count
  end

  test "should render as HTML" do
    pm = create_project_media
    get :oembed, id: pm.id, format: :html
    assert_no_match /iframe/, @response.body
  end

  test "should render as JSON" do
    pm = create_project_media
    get :oembed, id: pm.id, format: :json
    assert_match /iframe/, @response.body
    assert_no_match /doctype/, @response.body
    assert_response :success
  end

  test "should render whole HTML instead of iframe if request comes from Pender" do
    pm = create_project_media
    @request.headers['User-Agent'] = 'Mozilla/5.0 (compatible; Pender/0.1; +https://github.com/meedan/pender)'
    get :oembed, id: pm.id, format: :json
    assert_no_match /iframe/, @response.body
    assert_match /doctype/, @response.body
    assert_response :success
    @request.headers['User-Agent'] = ''
  end
end
