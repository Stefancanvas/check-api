require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class SearchControllerTest < ActionController::TestCase
  def setup
    super
    @controller = CheckSearch.new
  end

  test "should search with keyword" do
    keyword = {keyword: "search_title"}.to_json
    result = @controller.create(keyword)
    assert_empty result
    pender_url = CONFIG['pender_host'] + '/api/medias'
    url = 'http://test.com'
    response = '{"type":"media","data":{"url":"' + url + '/normalized","type":"item", "title": "search_title", "description":"search_desc"}}'
    WebMock.stub_request(:get, pender_url).with({ query: { url: url } }).to_return(body: response)
    m = create_media(account: create_valid_account, url: url)
    result = @controller.create(keyword)
    #assert_equal [m.id], result.map(&:id)
    # overide title then search
    create_media_information(media: m, title: 'search_title_a')
    result = @controller.create(keyword)
    assert_empty result
    # search by overriden title
    result = @controller.create({keyword: "search_title_a"}.to_json)
    assert_equal [m.id], result.map(&:id)
    # search in description and quote
    result = @controller.create({keyword: "search_desc"}.to_json)
    #assert_equal [m.id], result.map(&:id)
    result = @controller.create({keyword: "search_quote"}.to_json)
    #assert_equal [m.id], result.map(&:id)
    # add keyword to multiple medias
    m2 = create_valid_media
    create_media_information(media: m2, quote: 'search_quote')
    result = @controller.create({keyword: "search_quote"}.to_json)
    #assert_equal [m.id, m2.id].sort, result.map(&:id).sort
  end

  test "should search with context" do
    p = create_project
    keyword = {projects: [p.id]}.to_json
    result = @controller.create(keyword)
    assert_empty result
    m = create_valid_media
    create_media_information(media: m, title: 'search_title', project_id: p.id)
    result = @controller.create(keyword)
    assert_equal [m.id], result.map(&:id)
    # add annotation with another context
    p2 = create_project
    create_media_information(media: m, title: 'search_title', project_id: p2.id)
    result = @controller.create(keyword)
    assert_equal [m.id], result.map(&:id)
    # add another media to same context
    m2 = create_valid_media project_id: p.id
    create_media_information(media: m2, title: 'search_title', project_id: p.id)
    result = @controller.create(keyword)
    assert_equal [m.id, m2.id].sort, result.map(&:id).sort
  end

  test "should search with tags" do
    keyword = {tags: ['sports']}.to_json
    result = @controller.create(keyword)
    assert_empty result
    m = create_valid_media
    create_tag(tag: 'sports', annotated: m)
    pp m.annotations('tag')
    result = @controller.create(keyword)
    #assert_equal [m.id], result.map(&:id)
  end

end
