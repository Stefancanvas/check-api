require_relative '../test_helper'

class InvitationsControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::InvitationsController.new
    @request.env["devise.mapping"] = Devise.mappings[:api_user]
  end

  test "should accept invitation" do
    u = create_user
    t = create_team
    create_team_user team: t, user: u, role: 'owner'
    u1 = create_user email: 'test1@local.com'
    with_current_user_and_team(u, t) do
      members = {'contributor' => u1.email}
      User.send_user_invitation(members)
    end
    token = u1.read_attribute(:raw_invitation_token)
      u1.reload.invitation_token
    get :edit, invitation_token: token, slug: t.slug
    # assert_redirected_to "#{CONFIG['checkdesk_client']}/#{t.slug}"
    assert_nil u1.reload.invitation_token
  end

end
