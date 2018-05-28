require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'sidekiq/testing'

class TeamTest < ActiveSupport::TestCase
  def setup
    require 'sidekiq/testing'
    Sidekiq::Testing.inline!
    super
  end

  test "should create team" do
    assert_difference 'Team.count' do
      create_team
    end
    assert_difference 'Team.count' do
      u = create_user
      create_team current_user: u
    end
  end

  test "non members should not access private team" do
    u = create_user
    t = create_team
    pu = create_user
    pt = create_team private: true
    create_team_user team: pt, user: pu, role: 'owner'
    with_current_user_and_team(u, t) { Team.find_if_can(t.id) }
    assert_raise CheckPermissions::AccessDenied do
      with_current_user_and_team(u, pt) { Team.find_if_can(pt.id) }
    end
    with_current_user_and_team(pu, pt) { Team.find_if_can(pt.id) }
    tu = pt.team_users.last
    tu.status = 'requested'; tu.save!
    assert_raise CheckPermissions::AccessDenied do
      with_current_user_and_team(pu, pt) { Team.find_if_can(pt.id) }
    end
    assert_raise CheckPermissions::AccessDenied do
      with_current_user_and_team(create_user, pt) { Team.find_if_can(pt) }
    end
  end

  test "should update and destroy team" do
    u = create_user
    t = create_team
    create_team_user team: t, user: u, role: 'owner'
    t.name = 'meedan'; t.save!
    t.reload
    assert_equal t.name, 'meedan'
    # update team as owner
    u2 = create_user
    tu = create_team_user team: t, user: u2, role: 'owner'
    with_current_user_and_team(u2, t) { t.name = 'meedan_mod'; t.save! }
    t.reload
    assert_equal t.name, 'meedan_mod'
    assert_raise RuntimeError do
      with_current_user_and_team(u2, t) { t.destroy }
    end
    Rails.cache.clear
    u2 = User.find(u2.id)
    tu.role = 'journalist'; tu.save!
    assert_raise RuntimeError do
      with_current_user_and_team(u2, t) { t.save! }
    end
  end

  test "should not save team without name" do
    t = Team.new
    assert_not t.save
  end

  test "should not save team with invalid slugs" do
    assert_nothing_raised do
      create_team slug: "correct-الصهث-unicode"
    end
    assert_raise ActiveRecord::RecordInvalid do
      create_team slug: ''
    end
    assert_raise ActiveRecord::RecordInvalid do
      create_team slug: 'www'
    end
    assert_raise ActiveRecord::RecordInvalid do
      create_team slug: ''.rjust(64, 'a')
    end
    assert_raise ActiveRecord::RecordInvalid do
      create_team slug: ' some spaces '
    end
    assert_raise ActiveRecord::RecordInvalid do
      create_team slug: 'correct-الصهث-unicode'
    end
  end

  test "should create version when team is created" do
    User.current = create_user
    t = create_team
    assert_equal 1, t.versions.size
    User.current = nil
  end

  test "should create version when team is updated" do
    User.current = create_user
    t = create_team
    t.logo = random_string
    t.save!
    assert_equal 2, t.versions.size
    User.current = nil
  end

  test "should have users" do
    t = create_team
    u1 = create_user
    u2 = create_user
    assert_equal [], t.users
    t.users << u1
    t.users << u2
    assert_equal [u1, u2].sort, t.users.sort
  end

  test "should have team_user" do
    u = create_user
    t = create_team
    tu = create_team_user user: u, team: t
    with_current_user_and_team(u, t) do
      assert_equal tu, t.team_user
    end
  end

  test "should have team users" do
    t = create_team
    u1 = create_user
    u2 = create_user
    tu1 = create_team_user user: u1
    tu2 = create_team_user user: u2
    assert_equal [], t.team_users
    t.team_users << tu1
    t.team_users << tu2
    assert_equal [tu1, tu2].sort, t.team_users.sort
    assert_equal [u1, u2].sort, t.users.sort
  end

  test "should get logo from callback" do
    t = create_team
    assert_nil t.logo_callback('')
    file = 'http://checkdesk.org/users/1/photo.png'
    assert_nil t.logo_callback(file)
    file = 'http://ca.ios.ba/files/others/rails.png'
    assert_nil t.logo_callback(file)
  end

  test "should add user to team on team creation" do
    u = create_user
    assert_difference 'TeamUser.count' do
      with_current_user_and_team(u, nil) { create_team }
    end
  end

  test "should not add user to team on team creation" do
    assert_no_difference 'TeamUser.count' do
      create_team
    end
  end

  test "should be equivalent to set file or logo" do
    t = create_team logo: nil
    assert_match /team\.png$/, t.logo.url
    File.open(File.join(Rails.root, 'test', 'data', 'rails.png')) do |f|
      t.file = f
    end
    assert_match /rails\.png$/, t.logo.url
  end

  test "should not upload a logo that is not an image" do
    assert_no_difference 'Team.count' do
      assert_raises ActiveRecord::RecordInvalid do
        create_team logo: 'not-an-image.txt'
      end
    end
  end

  test "should not upload a big logo" do
    assert_no_difference 'Team.count' do
      assert_raises ActiveRecord::RecordInvalid do
        create_team logo: 'ruby-big.png'
      end
    end
  end

  test "should not upload a small logo" do
    assert_no_difference 'Team.count' do
      assert_raises ActiveRecord::RecordInvalid do
        create_team logo: 'ruby-small.png'
      end
    end
  end

  test "should have a default uploaded image" do
    t = create_team logo: nil
    assert_match /team\.png$/, t.logo.url
  end

  test "should have avatar" do
    t = create_team logo: nil
    assert_match /^http/, t.avatar
  end

  test "should have members count" do
    t = create_team
    t.users << create_user
    t.users << create_user
    assert_equal 2, t.members_count
  end

  test "should return number of projects" do
    t = create_team
    create_project team: t
    create_project team: t
    assert_equal 2, t.projects_count
  end

  test "should have a JSON version" do
    assert_kind_of Hash, create_team.as_json
  end

  test "should not send email when team is created" do
    u = create_user
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'TeamUser.count' do
        with_current_user_and_team(u, nil) { create_team }
      end
    end
  end

  test "should set current team when team is created by user" do
    t1 = create_team
    u = create_user
    create_team_user user: u, team: t1
    u.current_team_id = t1.id
    u.save!
    assert_equal t1, u.reload.current_team
    t2 = nil
    with_current_user_and_team(u, nil) { t2 = create_team }
    assert_equal t2, u.reload.current_team
  end

  test "should have settings" do
    t = create_team
    assert_equal({}, t.settings)
    assert_nil t.setting(:foo)
    t.set_foo = 'bar'
    t.save!
    assert_equal 'bar', t.reload.get_foo
    t.reset_foo
    t.save!
    assert_nil t.reload.get_foo
    t.settings = nil
    assert_nothing_raised do
      t.reset_foo
    end

    assert_raise NoMethodError do
      t.something
    end
  end

  test "should set contact" do
    t = create_team
    assert_difference 'Contact.count' do
      t.contact = { location: 'Salvador', phone: '557133330101', web: 'http://meedan.com' }.to_json
    end
    assert_no_difference 'Contact.count' do
      t.contact = { location: 'Bahia' }.to_json
    end
    assert_equal 'Bahia', t.reload.contacts.first.location
  end

  test "should validate Slack webhook" do
    t = create_team
    assert_raises ActiveRecord::RecordInvalid do
      t.set_slack_webhook = 'http://meedan.com'
      t.save!
    end
    assert_nothing_raised do
      t.set_slack_webhook = 'https://hooks.slack.com/services/123456'
      t.save!
    end
  end

  test "should downcase slug" do
    t = create_team slug: 'NewsLab'
    assert_equal 'newslab', t.reload.slug
  end

  test "should get permissions" do
    u = create_user
    t = create_team
    create_team_user team: t, user: u, role: 'owner'
    team = create_team
    perm_keys = ["read Team", "update Team", "destroy Team", "empty Trash", "create Project", "create Account", "create TeamUser", "create User", "create Contact"].sort

    # load permissions as owner
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }

    # load as editor
    tu = u.team_users.last; tu.role = 'editor'; tu.save!
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }

    # load as editor
    tu = u.team_users.last; tu.role = 'editor'; tu.save!
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }

    # load as journalist
    tu = u.team_users.last; tu.role = 'journalist'; tu.save!
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }

    # load as contributor
    tu = u.team_users.last; tu.role = 'contributor'; tu.save!
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }

    # load as authenticated
    tu = u.team_users.last; tu.role = 'editor'; tu.save!
    tu.delete
    with_current_user_and_team(u, t) { assert_equal perm_keys, JSON.parse(team.permissions).keys.sort }
  end

  test "should have custom verification statuses" do
    t = create_team
    value = {
      label: 'Field label',
      active: '2',
      default: '1',
      statuses: [
        { id: '1', label: 'Custom Status 1', completed: '', description: 'The meaning of this status', style: 'red' },
        { id: '2', label: 'Custom Status 2', completed: '', description: 'The meaning of that status', style: 'blue' }
      ]
    }
    assert_nothing_raised do
      t.set_media_verification_statuses(value)
      t.save!
    end
    assert_equal 2, t.get_media_verification_statuses[:statuses].size
  end

  test "should not save invalid custom verification statuses" do
    t = create_team
    value = {
      default: '1',
      active: '2',
      statuses: [
        { id: '1', label: 'Custom Status 1', description: 'The meaning of this status' },
        { id: '2', label: 'Custom Status 2', description: 'The meaning of that status' }
      ]
    }
    assert_raises ActiveRecord::RecordInvalid do
      t.set_media_verification_statuses(value)
      t.save!
    end
  end

  test "should not save invalid custom verification status" do
    t = create_team
    value = {
      label: 'Field label',
      default: '1',
      active: '2',
      statuses: [
        { id: '1', label: 'Custom Status 1' },
        { id: '2', label: 'Custom Status 2', description: 'The meaning of that status' },
        { id: '3', label: '', description: 'The meaning of that status' },
        { id: '', label: 'Custom Status 4', description: 'The meaning of that status' }
      ]
    }
    assert_raises ActiveRecord::RecordInvalid do
      t.set_media_verification_statuses(value)
      t.save!
    end
  end

  test "should not save custom verification status if the default doesn't match any status id" do
    t = create_team
    variations = [
      {
        label: 'Field label',
        default: '10',
        active: '2',
        statuses: [
          { id: '1', label: 'Custom Status 1', description: 'The meaning of this status', style: 'red' },
          { id: '2', label: 'Custom Status 2', description: 'The meaning of that status', style: 'blue' }
        ]
      },
      {
        label: 'Field label',
        default: '1',
        active: '2',
        statuses: []
      }
    ]

    variations.each do |value|
      assert_raises ActiveRecord::RecordInvalid do
        t.set_media_verification_statuses(value)
        t.save!
      end
    end
  end

  test "should remove empty statuses before save custom verification statuses" do
    t = create_team
    value = {
      label: 'Field label',
      default: '1',
      active: '1',
      statuses: [
        { id: '1', label: 'Valid status', completed: '', description: 'The meaning of this status', style: 'red' },
        { id: '', label: '', completed: '', description: 'Status with empty id and label', style: 'blue' }
      ]
    }
    assert_nothing_raised do
      t.media_verification_statuses = value
      t.save!
    end
    assert_equal 1, t.get_media_verification_statuses[:statuses].size
  end

  test "should not save custom verification statuses if default or statuses is empty" do
    t = create_team
    value = {
      label: 'Field label',
      completed: '',
      default: '',
      active: '',
      statuses: []
    }
    assert_nothing_raised do
      t.media_verification_statuses = value
      t.save!
    end
    assert t.get_media_verification_statuses.nil?
  end

  test "should not save custom verification status if it is not a hash" do
    t = create_team
    value = 'invalid_status'
    assert_raises ActiveRecord::RecordInvalid do
      t.set_media_verification_statuses(value)
      t.save!
    end
  end

  test "should not change custom statuses that are already used in reports" do
    create_translation_status_stuff
    create_verification_status_stuff(false)
    t = create_team
    p = create_project team: t
    pm = create_project_media project: p
    s = pm.last_verification_status_obj
    value = {
      label: 'Field label',
      default: '1',
      active: '2',
      statuses: [
        { id: '1', label: 'Custom Status 1', completed: '', description: '', style: 'red' },
        { id: '2', label: 'Custom Status 2', completed: '', description: '', style: 'blue' }
      ]
    }
    t.set_limits_custom_statuses(true)
    t.save!
    t = Team.find(t.id)
    assert_raises ActiveRecord::RecordInvalid do
      t.set_media_verification_statuses(value)
      t.save!
    end
    assert_nothing_raised do
      value[:statuses] << { id: s.status, label: s.status, completed: '', description: '', style: 'blue' }
      t.set_media_verification_statuses(value)
      t.save!
    end
  end

  test "should not create team with 'check' slug" do
    assert_raises ActiveRecord::RecordInvalid do
      create_team slug: 'check'
    end
  end

  test "should set background color and border color equal to color on verification statuses" do
    t = create_team
    value = {
      label: 'Test',
      statuses: [{
        id: 'first',
        label: 'Analyzing',
        description: 'Testing',
        style: {
          color: "blue"
        }}]
    }.with_indifferent_access
    t.media_verification_statuses = value
    t.save
    statuses = t.get_media_verification_statuses[:statuses].first
    %w(color backgroundColor borderColor).each do |k|
      assert_equal 'blue', statuses['style'][k]
    end
  end

  test "should not return backgroundColor and borderColor on AdminUI media custom statuses" do
    t = create_team
    value = {
      label: 'Field label',
      default: '1',
      active: '1',
      statuses: [
        { id: '1', label: 'Custom Status 1', description: 'The meaning of this status', style: { color: 'red', backgroundColor: 'red', borderColor: 'red'} },
      ]
    }
    t.media_verification_statuses = value
    t.save

    status = t.get_media_verification_statuses[:statuses]
    assert_equal ['backgroundColor', 'borderColor', 'color'], status.first[:style].keys.sort

    status = t.media_verification_statuses[:statuses]
    assert_equal ['color'], status.first[:style].keys.sort
   end

  test "should return statuses as array after set statuses without it" do
    t = create_team
    value = {
      label: 'Field label',
      default: '1',
      active: '1'
    }
    t.media_verification_statuses = value

    assert_nil t.get_media_verification_statuses[:statuses]
    assert_equal [], t.media_verification_statuses[:statuses]
  end

   test "should not save statuses if default is present and statuses is missing" do
    t = create_team
    value = {
        label: 'Field label',
        default: '1',
        active: '1'
    }
    t.media_verification_statuses = value
    t.save

    assert Team.find(t.id).media_verification_statuses.nil?
  end

  test "should set verification statuses to settings" do
    t = create_team
    value = { label: 'Test', active: 'first', default: 'first', statuses: [{ id: 'first', label: 'Analyzing', description: 'Testing', style: 'bar' }]}.with_indifferent_access
    t.media_verification_statuses = value
    t.source_verification_statuses = value
    t.save
    assert_equal value, t.get_media_verification_statuses
    assert_equal value, t.get_source_verification_statuses
  end

  test "should set slack_notifications_enabled" do
    t = create_team
    t.slack_notifications_enabled = true
    t.save
    assert t.get_slack_notifications_enabled
  end

  test "should set slack_webhook" do
    t = create_team
    t.slack_webhook = 'https://hooks.slack.com/services/123456'
    t.save
    assert_equal 'https://hooks.slack.com/services/123456', t.get_slack_webhook
  end

  test "should set slack_channel" do
    t = create_team
    t.slack_channel = '#my-channel'
    t.save
    assert_equal '#my-channel', t.reload.get_slack_channel
  end

  test "should protect attributes from mass assignment" do
    raw_params = { name: 'My team', slug: 'my-team' }
    params = ActionController::Parameters.new(raw_params)

    assert_raise ActiveModel::ForbiddenAttributesError do
      Team.create(params)
    end
  end

  test "should destroy related items" do
    u = create_user
    t = create_team
    id = t.id
    t.description = 'update description'; t.save!
    tu = create_team_user user: u, team: t
    p = create_project team: t
    pm = create_project_media project: p
    a = create_account team: t
    c = create_contact team: t
    RequestStore.store[:disable_es_callbacks] = true
    t.destroy
    assert_equal 0, Project.where(team_id: id).count
    assert_equal 0, TeamUser.where(team_id: id).count
    assert_equal 0, Account.where(team_id: id).count
    assert_equal 0, Contact.where(team_id: id).count
    assert_equal 0, ProjectMedia.where(project_id: p.id).count
    RequestStore.store[:disable_es_callbacks] = false
  end

  test "should have search id" do
    t = create_team
    assert_not_nil t.search_id
  end

  test "should save checklist if it is blank or nil" do
    t = create_team
    variations = [
      nil,
      ''
    ]
    variations.each do |value|
      assert_nothing_raised do
        t.set_checklist(value)
        t.save!
      end
    end
  end

  test "should save valid checklist" do
    t = create_team
    value =  [{ label: 'A task', type: 'free_text', description: '', projects: [], options: []}]
    assert_nothing_raised do
      t.set_checklist(value)
      t.save!
    end
  end

  test "should not save checklist if is not valid" do
    t = create_team
    variations = [
      'invalid_checklist',
      ['invalid_checklist'],
      [{ label: 'A task' }],
      [{ label: 'A task', type: 'free_text' }],
      [{ description: 'A task' }],
      [{ type: 'free_text', description: '', projects: []}]
    ]
    variations.each do |value|
      assert_raises ActiveRecord::RecordInvalid do
        t.set_checklist(value)
        t.save!
      end
    end
  end

  test "should remove empty task without label before save checklist" do
    t = create_team
    variations = [
      [{ label: '' }],
      [{ description: 'A task' }],
      [{ type: 'free_text', description: '', projects: []}]
    ]
    variations.each do |value|
      assert_nothing_raised do
        t.checklist = value
        t.save!
      end
      assert t.get_checklist.empty?
    end
  end

  test "should return checklist options as hash instead of json when call checklist" do
    t = create_team
    value = [{
      label: "Task one",
      type: "single_choice",
      description: "It is a single choice task",
      options: [{ "label": "option 1" },{ "label": "option 2" }]
    }]
    t.checklist = value
    t.save!
    assert_equal [{"label"=>"option 1"}, {"label"=>"option 2"}], t.get_checklist.first[:options]
    assert_equal [{"label"=>"option 1"}, {"label"=>"option 2"}], t.checklist.first[:options]
  end

  test "should support the json editor format on checklist" do
    t = create_team
    value =  [{ label: 'A task', type: 'single_choice', description: '', projects: [], options: {"0"=>{"label"=>"option 1"}, "1"=>{"label"=>"option 2"}}}]
    assert_nothing_raised do
      t.checklist = value
      t.save!
    end
    assert_equal [{"label"=>"option 1"}, {"label"=>"option 2"}], t.checklist.first[:options]
  end

  test "should return checklist options as array after submit task without it" do
    t = create_team
    value = [{
      label: "Task one",
      type: "single_choice",
      description: "It is a single choice task",
    }]
    t.checklist = value
    t.save!
    assert_nil t.get_checklist.first[:options]
    assert_equal [], t.checklist.first[:options]
  end

  test "should return checklist projects as array after submit task without it" do
    t = create_team
    value = [{
      label: "Task one",
      type: "free_text",
      description: "It is a single choice task",
    }]
    t.checklist = value
    t.save!
    assert_nil t.get_checklist.first[:projects]
    assert_equal [], t.checklist.first[:projects]
  end

  test "should return checklist mapping as hash after submit task without it" do
    t = create_team
    value = [{
      label: "Task one",
      type: "free_text",
      description: "It is a free text task",
    }]
    t.checklist = value
    t.save!
    assert_nil t.get_checklist.first[:mapping]
    assert_equal({"type" => "text", "match" => "", "prefix" => ""}, t.checklist.first[:mapping])
  end

  test "should remove all items from checklist" do
    t = create_team
    value =  [{ label: 'A task', type: 'free_text', description: '', projects: [], options: []}]
    t.set_checklist(value)
    t.save!

    assert_nothing_raised do
      t.set_checklist([])
      t.save!
    end
    assert_equal [], t.checklist
  end

  test "should save valid slack_channel" do
    t = create_team
    value =  "#slack_channel"
    assert_nothing_raised do
      t.set_slack_channel(value)
      t.save!
    end
  end

  test "should not save slack_channel if is not valid" do
    t = create_team
    value = 'invalid_channel'
    assert_raises ActiveRecord::RecordInvalid do
      t.set_slack_channel(value)
      t.save!
    end
  end

  test "should be private by default" do
    Team.delete_all
    t = Team.new
    t.name = 'Test'
    t.slug = 'test'
    t.save!
    assert t.reload.private
  end

  test "should add or remove item to or from checklist" do
    t = create_team
    value =  [{ label: 'A task', type: 'free_text', description: '', projects: [], options: [] }]
    t.set_checklist(value)
    t.save!
    assert_equal ['A task'], t.reload.get_checklist.collect{ |t| t[:label] }
    t.add_auto_task = { label: 'Another task', type: 'free_text', description: '', projects: [], options: [] }
    t.save!
    assert_equal ['A task', 'Another task'], t.reload.get_checklist.collect{ |t| t[:label] }
    t.remove_auto_task = 'A task'
    t.save!
    assert_equal ['Another task'], t.reload.get_checklist.collect{ |t| t[:label] }
  end

  test "should archive sources, projects and project medias when team is archived" do
    Sidekiq::Testing.inline! do
      t = create_team
      p1 = create_project
      p2 = create_project team: t
      s1 = create_source
      s2 = create_source team: t
      pm1 = create_project_media
      pm2 = create_project_media project: p2
      pm3 = create_project_media project: p2
      t.archived = true
      t.save!
      assert !pm1.reload.archived
      assert pm2.reload.archived
      assert pm3.reload.archived
      assert !p1.reload.archived
      assert p2.reload.archived
      assert !s1.reload.archived
      assert s2.reload.archived
    end
  end

  test "should archive sources, project and project medias in background when team is archived" do
    Sidekiq::Testing.fake! do
      t = create_team
      p = create_project team: t
      pm = create_project_media project: p
      n = Sidekiq::Extensions::DelayedClass.jobs.size
      t = Team.find(t.id)
      t.archived = true
      t.save!
      assert_equal n + 1, Sidekiq::Extensions::DelayedClass.jobs.size
    end
  end

  test "should not archive project and project medias in background if team is updated but archived flag does not change" do
    Sidekiq::Testing.fake! do
      t = create_team
      p = create_project team: t
      pm = create_project_media project: p
      n = Sidekiq::Extensions::DelayedClass.jobs.size
      t = Team.find(t.id)
      t.name = random_string
      t.save!
      assert_equal n, Sidekiq::Extensions::DelayedClass.jobs.size
    end
  end

  test "should restore sources, project and project medias when team is restored" do
    Sidekiq::Testing.inline! do
      t = create_team
      p1 = create_project team: t
      p2 = create_project
      s1 = create_source team: t
      s2 = create_source
      pm1 = create_project_media
      pm2 = create_project_media project: p1
      pm3 = create_project_media project: p1
      t.archived = true
      t.save!
      assert !pm1.reload.archived
      assert pm2.reload.archived
      assert pm3.reload.archived
      assert p1.reload.archived
      assert !p2.reload.archived
      t = Team.find(t.id)
      t.archived = false
      t.save!
      assert !pm1.reload.archived
      assert !pm2.reload.archived
      assert !pm3.reload.archived
      assert !p1.reload.archived
      assert !p2.reload.archived
      assert !s1.reload.archived
      assert !s2.reload.archived
    end
  end

  test "should delete sources, project and project medias in background when team is deleted" do
    Sidekiq::Testing.fake! do
      t = create_team
      u = create_user
      create_team_user user: u, team: t, role: 'owner'
      p = create_project team: t
      pm = create_project_media project: p
      n = Sidekiq::Extensions::DelayedClass.jobs.size
      t = Team.find(t.id)
      with_current_user_and_team(u, t) do
       t.destroy_later
      end
      assert_equal n + 1, Sidekiq::Extensions::DelayedClass.jobs.size
    end
  end

  test "should delete sources, projects and project medias when team is deleted" do
    Sidekiq::Testing.inline! do
      t = create_team
      u = create_user
      create_team_user user: u, team: t, role: 'owner'
      p1 = create_project
      p2 = create_project team: t
      s1 = create_source
      s2 = create_source team: t
      pm1 = create_project_media
      pm2 = create_project_media project: p2
      pm3 = create_project_media project: p2
      c = create_comment annotated: pm2
      RequestStore.store[:disable_es_callbacks] = true
      with_current_user_and_team(u, t) do
        t.destroy_later
      end
      RequestStore.store[:disable_es_callbacks] = false
      assert_not_nil ProjectMedia.where(id: pm1.id).last
      assert_nil ProjectMedia.where(id: pm2.id).last
      assert_nil ProjectMedia.where(id: pm3.id).last
      assert_not_nil Project.where(id: p1.id).last
      assert_nil Project.where(id: p2.id).last
      assert_not_nil Source.where(id: s1.id).last
      assert_nil Source.where(id: s2.id).last
      assert_nil Comment.where(id: c.id).last
    end
  end

  test "should not delete team later if doesn't have permission" do
    u = create_user
    t = create_team
    create_team_user user: u, team: t, role: 'contributor'
    with_current_user_and_team(u, t) do
      assert_raises RuntimeError do
        t.destroy_later
      end
    end
  end

  test "should empty trash in background" do
    Sidekiq::Testing.fake! do
      t = create_team
      u = create_user
      create_team_user user: u, team: t, role: 'owner'
      n = Sidekiq::Extensions::DelayedClass.jobs.size
      t = Team.find(t.id)
      with_current_user_and_team(u, t) do
       t.empty_trash = 1
      end
      assert_equal n + 1, Sidekiq::Extensions::DelayedClass.jobs.size
    end
  end

  test "should empty trash if has permissions" do
    Sidekiq::Testing.inline! do
      t = create_team
      u = create_user
      create_team_user user: u, team: t, role: 'owner'
      p = create_project team: t
      3.times { pm = create_project_media(project: p); pm.archived = true; pm.save! }
      2.times { create_project_media(project: p) }
      RequestStore.store[:disable_es_callbacks] = true
      with_current_user_and_team(u, t) do
        assert_nothing_raised do
          assert_difference 'ProjectMedia.count', -3 do
            t.empty_trash = 1
          end
        end
      end
      RequestStore.store[:disable_es_callbacks] = false
    end
  end

  test "should not empty trash if has no permissions" do
    Sidekiq::Testing.inline! do
      t = create_team
      u = create_user
      create_team_user user: u, team: t, role: 'contributor'
      p = create_project team: t
      3.times { pm = create_project_media(project: p); pm.archived = true; pm.save! }
      2.times { create_project_media(project: p) }
      with_current_user_and_team(u, t) do
        assert_raises RuntimeError do
          assert_no_difference 'ProjectMedia.count' do
            t.empty_trash = 1
          end
        end
      end
    end
  end

  test "should get trash size" do
    t = create_team
    u = create_user
    create_team_user team: t, user: u, role: 'owner'
    p = create_project team: t
    pm1 = create_project_media project: p
    pm2 = create_project_media project: p
    with_current_user_and_team(u, t) do
      2.times { create_comment annotated: pm1 }
      3.times { create_comment annotated: pm2 }
    end
    pm1.archived = true
    pm1.save!
    pm2.archived = true
    pm2.save!
    size = t.reload.trash_size
    assert_equal 2, size[:project_media]
    assert_equal 5, size[:annotation]
  end

  test "should get search id" do
    t = create_team
    assert_kind_of CheckSearch, t.check_search_team
  end

  test "should get GraphQL id" do
    t = create_team
    assert_kind_of String, t.graphql_id
  end

  test "should have limits" do
    t = Team.new
    t.name = random_string
    t.slug = "slug-#{random_number}"
    t.save!
    assert_equal Team.plans[:free], t.reload.limits
  end

  test "should not change limits if not super admin" do
    t = create_team
    u = create_user
    create_team_user team: t, user: u, role: 'owner'
    with_current_user_and_team(u, t) do
      assert_raises ActiveRecord::RecordInvalid do
        t.limits = { changed: true }
        t.save!
      end
    end
  end

  test "should change limits if super admin" do
    t = create_team
    u = create_user is_admin: true
    create_team_user team: t, user: u, role: 'owner'
    with_current_user_and_team(u, t) do
      assert_nothing_raised do
        t.limits = { changed: true }
        t.save!
      end
    end
  end

  test "should not set custom statuses if limited" do
    t = create_team
    t.set_limits_custom_statuses(false)
    t.save!
    t = Team.find(t.id)
    value = {
      label: 'Field label',
      default: '1',
      active: '2',
      statuses: [
        { id: '1', label: 'Custom Status 1', description: 'The meaning of this status', style: 'red' },
        { id: '2', label: 'Custom Status 2', description: 'The meaning of that status', style: 'blue' }
      ]
    }
    assert_raises ActiveRecord::RecordInvalid do
      t.set_media_verification_statuses(value)
      t.save!
    end
  end

  test "should not save checklist if limited" do
    t = create_team
    t.set_limits_custom_tasks_list(false)
    t.save!
    t = Team.find(t.id)
    value =  [{ label: 'A task', type: 'free_text', description: '', projects: [], options: []}]
    assert_raises ActiveRecord::RecordInvalid do
      t.set_checklist(value)
      t.save!
    end
  end

  test "should return the json schema url" do
    t = create_team
    fields = {
      'media_verification_statuses': 'statuses',
      'source_verification_statuses': 'statuses',
      'checklist': 'checklist',
      'limits': 'limits'
    }

    fields.each do |field, filename|
      assert_equal URI.join(CONFIG['checkdesk_base_url'], "/#{filename}.json"), t.json_schema_url(field.to_s)
    end
  end

  test "should have public team id" do
    t = create_team
    assert_kind_of String, t.public_team_id
  end

  test "should have public team alias" do
    t = create_team
    assert_equal t, t.public_team
  end

  test "should hide names in embeds" do
    t = create_team
    assert !t.get_hide_names_in_embeds
    t.hide_names_in_embeds = 1
    t.save!
    assert t.get_hide_names_in_embeds
  end

  test "should clear embed caches if team setting is changed" do
    ProjectMedia.stubs(:clear_caches).times(3)
    t = create_team
    p = create_project team: t
    3.times { create_project_media(project: p) }
    t.hide_names_in_embeds = 1
    t.save!
    ProjectMedia.unstub(:clear_caches)
  end

  test "should enable or disable archivers" do
    t = create_team
    assert !t.get_archive_keep_backup_enabled
    t.archive_keep_backup_enabled = true
    t.save!
    assert t.reload.get_archive_keep_backup_enabled

    assert !t.get_archive_pender_archive_enabled
    t.archive_pender_archive_enabled = true
    t.save!
    assert t.reload.get_archive_pender_archive_enabled

    assert !t.get_archive_archive_is_enabled
    t.archive_archive_is_enabled = true
    t.save!
    assert t.reload.get_archive_archive_is_enabled
  end

  test "should return team plan" do
    t = create_team
    t.set_limits_max_number_of_projects = 5
    t.save!
    assert_equal 'free', t.plan
    t = create_team
    t.limits = {}
    t.save!
    assert_equal 'pro', t.plan
  end

  test "should duplicate a team and copy team users and contacts" do
    team = create_team name: 'Team A', logo: 'rails.png'

    u1 = create_user
    u2 = create_user
    create_team_user team: team, user: u1, role: 'owner', status: 'member'
    create_team_user team: team, user: u2, role: 'editor', status: 'invited'
    create_contact team: team

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert_equal 2, TeamUser.where(team_id: copy.id).count
    assert_equal 1, Contact.where(team_id: copy.id).count

    # team attributes
    assert_equal "#{team.slug}-copy-1", copy.slug
    %w(name archived private description).each do |att|
      assert_equal team.send(att), copy.send(att)
    end

    # team users
    assert_equal team.team_users.map { |tu| [tu.user.id, tu.role, tu.status] }, copy.team_users.map { |tu| [tu.user.id, tu.role, tu.status] }

    # contacts
    assert_equal team.contacts.map(&:web), copy.contacts.map(&:web)

    assert_difference 'Team.count', -1 do
      copy.destroy
    end
    assert_equal 2, TeamUser.where(team_id: team.id).count
    assert_equal 1, Contact.where(team_id: team.id).count
  end

  test "should duplicate a team and copy projects and update checklist" do
    team = create_team name: 'Team A', logo: 'rails.png'

    project1 = create_project team: team, title: 'Project 1'
    project2 = create_project team: team, title: 'Project 2'
    value = [{
      label: "Task one",
      type: "free_text",
      description: "It is a single free text task",
      projects: [project1.id, project2.id]
    }]
    team.checklist = value; team.save!

    team.add_auto_task = { label: 'Task 2', type: 'free_text', description: '', projects: [] }
    team.save!

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert_equal 2, Project.where(team_id: copy.id).count

    # projects
    assert_equal team.projects.map(&:title), copy.projects.map(&:title)

    # change projects ids on checklist
    copy_p1 = copy.projects.find_by_title('Project 1')
    copy_p2 = copy.projects.find_by_title('Project 2')
    assert_equal [copy_p1.id, copy_p2.id], copy.get_checklist.first[:projects]

    # tasks
    assert_equal ['Task one', 'Task 2'], copy.get_checklist.map { |t| t[:label]}

    assert_difference 'Team.count', -1 do
      copy.destroy
    end
    assert_equal 2, Project.where(team_id: team.id).count
  end

  test "should duplicate a team and copy sources and project medias" do
    team = create_team name: 'Team A', logo: 'rails.png'
    u = create_user
    project = create_project team: team, user: u
    source = create_source user: u
    source.team = team; source.save
    account = create_account user: u, team: team, source: source
    create_project_source user: u, team: team, project: project, source: source

    media = create_media account: account, user: u
    pm1 = create_project_media user: u, team: team, project: project, media: media

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    assert_equal 1, Source.where(team_id: copy.id).count
    assert_equal 1, project.project_medias.count
    assert_equal 2, project.project_sources.count

    copy_p = copy.projects.find_by_title(project.title)

    # sources
    assert_equal team.sources.map { |s| [s.user.id, s.slogan, s.file.path ] }, copy.sources.map { |s| [s.user.id, s.slogan, s.file.path ] }

    # project sources
    assert_not_equal project.project_sources.map(&:source).sort, copy_p.project_sources.map(&:source).sort

    # project medias
    assert_equal project.project_medias.map(&:media).sort, copy_p.project_medias.map(&:media).sort

    assert_difference 'Team.count', -1 do
      copy.destroy
    end
    assert_equal 1, Source.where(team_id: team.id).count
    assert_equal 1, project.project_medias.count
    assert_equal 2, project.project_sources.count
    RequestStore.store[:disable_es_callbacks] = false
  end

  test "should duplicate a team and annotations" do
    team = create_team name: 'Team A', logo: 'rails.png'

    project = create_project team: team, title: 'Project'
    u = create_user
    pm = create_project_media user: u, team: team, project: project

    create_comment annotated: pm
    create_tag annotated: pm
    create_flag annotated: pm

    at = create_annotation_type annotation_type: 'response'
    ft1 = create_field_type field_type: 'task_reference'
    ft2 = create_field_type field_type: 'text'
    create_field_instance annotation_type_object: at, field_type_object: ft1, name: 'task'
    create_field_instance annotation_type_object: at, field_type_object: ft2, name: 'response'

    task = create_task annotated: pm, annotator: u
    task.response = { annotation_type: 'response', set_fields: { response: 'Test', task: task.id.to_s }.to_json }.to_json; task.save!
    original_annotations_count = pm.annotations.size

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)

    copy_p = copy.projects.find_by_title('Project')
    copy_pm = copy_p.project_medias.first

    assert_equal ["comment", "flag", "response", "tag", "task"], copy_pm.annotations.map(&:annotation_type).sort
    assert_equal original_annotations_count, copy_pm.annotations.size

    assert_difference 'Team.count', -1 do
      copy.destroy
    end
    assert_equal original_annotations_count, ProjectMedia.find(pm.id).annotations.size
    RequestStore.store[:disable_es_callbacks] = false
  end

  test "should generate slug for copy based on original" do
    team1 = create_team slug: 'team-a'
    team2 = create_team slug: 'team-a-copy-1'
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team1)
    RequestStore.store[:disable_es_callbacks] = false
    assert_equal 'team-a-copy-2', copy.slug
  end

  test "should copy versions on team duplication" do
    t = create_team
    u = create_user
    u.is_admin = true;u.save
    create_team_user team: t, user: u, role: 'owner'
    with_current_user_and_team(u, t) do
      p1 = create_project team: t
      pm = create_project_media user: u, team: t, project: p1
      p2 = create_project team: t
      pm.project_id = p2.id; pm.save!
      RequestStore.store[:disable_es_callbacks] = true
      copy = Team.duplicate(t, u)
      assert copy.is_a?(Team)
      RequestStore.store[:disable_es_callbacks] = false
    end
    User.current = nil
  end

  test "should copy versions on team duplication and destroy it when embed has previous version" do
    t = create_team
    u = create_user
    u.is_admin = true;u.save
    create_team_user team: t, user: u, role: 'owner'
    with_current_user_and_team(u, t) do
      p = create_project team: t
      pm1 = create_project_media user: u, team: t, project: p
      pm2 = create_project_media user: u, team: t, project: p
      e = create_embed annotated: pm1, title: 'Foo', annotator: u
      e.title = 'bar';e.annotated = pm2; e.save!
      RequestStore.store[:disable_es_callbacks] = true
      copy = Team.duplicate(t, u)

      copy_pm1 = copy.projects.first.project_medias.first
      copy_pm2 = copy.projects.first.project_medias.last
      copy_e = copy_pm2.annotations('embed').last
      v = copy_e.versions.last
      assert_equal copy_e.id.to_s, v.item_id
      assert_equal [copy_e.id, copy_pm2.id], [v.get_object['id'], v.get_object['annotated_id']]
      assert_equal [copy_pm1.id, copy_pm2.id], v.get_object_changes['annotated_id']
      obj_after = JSON.parse v.object_after
      assert_equal [copy_e.id, copy_pm2.id], [obj_after['id'], obj_after['annotated_id']]
      assert copy.destroy!
      RequestStore.store[:disable_es_callbacks] = false
    end
    User.current = nil
  end

  test "should generate slug with 63 maximum chars" do
    team = create_team slug: 'lorem-ipsum-dolor-sit-amet-consectetur-adipiscing-elit-morbi-at'
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert_equal 'lorem-ipsumsit-amet-consectetur-adipiscing-elit-morbi-at-copy-1', copy.slug
  end

  test "should not copy invalid statuses" do
    team = create_team
    value = { default: '1', active: '1' }
    team.set_media_verification_statuses(value);team.save(validate: false)
    assert !team.valid?
    assert !team.errors[:statuses].blank?
    assert_equal value, team.get_media_verification_statuses(value)
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert copy.errors[:statuses].blank?
    assert_equal team.get_media_verification_statuses(value), copy.get_media_verification_statuses(value)
  end

  test "should not notify slack if is being copied" do
    create_slack_bot
    team = create_team
    user = create_user
    create_team_user team: team, user: user, role: 'owner'
    project = create_project team: team, title: 'Project'
    pm = create_project_media project: project
    source = create_source user: user
    source.team = team; source.save

    assert !Bot::Slack.default.nil?
    Bot::Slack.any_instance.stubs(:notify_slack).never
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert copy.valid?
    Bot::Slack.any_instance.unstub(:notify_slack)
  end

  test "should not set active status if task is being copied" do
    create_translation_status_stuff
    create_verification_status_stuff(false)
    create_slack_bot
    team = create_team
    project = create_project team: team, title: 'Project'
    pm = create_project_media project: project
    task = create_task annotated: pm, required: true
    create_annotation_type annotation_type: 'response'
    task.response = { annotation_type: 'response', set_fields: { response: 'Test', task: task.id.to_s }.to_json }.to_json; task.save!
    s = pm.get_annotations('verification_status').last.load; s.status = 'verified'; s.save!

    ProjectMedia.any_instance.stubs(:set_active_status).never
    assert !Bot::Slack.default.nil?
    Bot::Slack.any_instance.stubs(:notify_slack).never
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert copy.valid?
    ProjectMedia.any_instance.unstub(:set_active_status)
    Bot::Slack.any_instance.unstub(:notify_slack)
  end

  test "should duplicate team with duplicated source" do
    team = create_team
    user = create_user
    source = create_source user: user, team: team
    duplicated_source = source.dup
    duplicated_source.save(validate: false)

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert Team.exists?(copy.id)
  end

  test "should copy comment image" do
    team = create_team name: 'Team A'

    project = create_project team: team, title: 'Project'
    u = create_user
    pm = create_project_media user: u, team: team, project: project
    c = create_comment annotated: pm, file: 'rails.png'

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false

    copy_p = copy.projects.find_by_title('Project')
    copy_pm = copy_p.project_medias.first
    copy_comment = copy_pm.get_annotations('comment').first.load
    assert File.exist?(copy_comment.file.path)
  end

  test "should skip validation on team with big image" do
    team = create_team
    user = create_user
    pm = create_project_media team: team, project: create_project(team: team)
    c = create_comment annotated: pm
    File.open(File.join(Rails.root, 'test', 'data', 'rails-photo.jpg')) do |f|
      c.file = f
    end
    c.save(validate: false)

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert copy.valid?
  end

  test "should generate new token on duplication" do
    team = create_team
    project = create_project team: team
    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    copy_p = copy.projects.find_by_title(project.title)
    assert_not_equal project.token, copy_p.token
  end

  test "should duplicate a team when project is archived" do
    team = create_team name: 'Team A', logo: 'rails.png'
    project = create_project team: team

    pm1 = create_project_media team: team, project: project
    project.archived = true; project.save!

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false

    copy_p = copy.projects.find_by_title(project.title)
    assert_equal project.project_medias.map(&:media).sort, copy_p.project_medias.map(&:media).sort
  end

  test "should duplicate a team with sources and projects when team is archived" do
    team = create_team name: 'Team A', logo: 'rails.png'
    project = create_project team: team

    source = create_source
    source.team = team; source.save

    team.archived = true; team.save!

    RequestStore.store[:disable_es_callbacks] = true
    copy = Team.duplicate(team)
    RequestStore.store[:disable_es_callbacks] = false
    assert_equal 1, Project.where(team_id: copy.id).count
    assert_equal 1, Source.where(team_id: copy.id).count
  end

  test "should reset current team when team is deleted" do
    t = create_team
    u = create_user
    create_team_user user: u, team: t
    u.current_team_id = t.id
    u.save!
    assert_not_nil u.reload.current_team_id
    t.destroy
    assert_nil u.reload.current_team_id
  end

  test "should notify Airbrake when duplication raises error" do
    team = create_team
    RequestStore.store[:disable_es_callbacks] = true
    Airbrake.configuration.stubs(:api_key).returns('token')
    Airbrake.stubs(:notify).once
    Team.any_instance.stubs(:save).with(validate: false).raises(RuntimeError)

    assert_nil Team.duplicate(team)
    Airbrake.configuration.unstub(:api_key)
    Airbrake.unstub(:notify)
    Team.any_instance.unstub(:save)
    RequestStore.store[:disable_es_callbacks] = false
  end

  test "should not save custom statuses if active and default values are not set" do
    t = create_team
    value = {
      label: 'Field label',
      default: '1',
      statuses: [
        { id: '1', label: 'Custom Status 1', completed: '', description: 'The meaning of this status', style: 'red' },
        { id: '2', label: 'Custom Status 2', completed: '', description: 'The meaning of that status', style: 'blue' }
      ]
    }
    assert_raises ActiveRecord::RecordInvalid do
      t = Team.find(t.id)
      t.set_media_verification_statuses(value)
      t.save!
    end
    assert_raises ActiveRecord::RecordInvalid do
      t = Team.find(t.id)
      t.set_media_translation_statuses(value)
      t.save!
    end
    value = {
      label: 'Field label',
      active: '1',
      statuses: [
        { id: '1', label: 'Custom Status 1', completed: '', description: 'The meaning of this status', style: 'red' },
        { id: '2', label: 'Custom Status 2', completed: '', description: 'The meaning of that status', style: 'blue' }
      ]
    }
    assert_raises ActiveRecord::RecordInvalid do
      t = Team.find(t.id)
      t.set_media_verification_statuses(value)
      t.save!
    end
    assert_raises ActiveRecord::RecordInvalid do
      t = Team.find(t.id)
      t.set_media_translation_statuses(value)
      t.save!
    end
    value = {
      label: 'Field label',
      default: '1',
      active: '2',
      statuses: [
        { id: '1', label: 'Custom Status 1', completed: '', description: 'The meaning of this status', style: 'red' },
        { id: '2', label: 'Custom Status 2', completed: '', description: 'The meaning of that status', style: 'blue' }
      ]
    }
    assert_nothing_raised do
      t = Team.find(t.id)
      t.set_media_verification_statuses(value)
      t.save!
    end
    assert_nothing_raised do
      t = Team.find(t.id)
      t.set_media_translation_statuses(value)
      t.save!
    end
  end
end
