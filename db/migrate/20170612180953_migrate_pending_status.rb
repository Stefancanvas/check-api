class MigratePendingStatus < ActiveRecord::Migration[4.2]
  def change
    if CONFIG['app_name'] === 'Check' && !defined?(Status).nil?
      url = "http://#{CONFIG['elasticsearch_host']}:#{CONFIG['elasticsearch_port']}"
      client = Elasticsearch::Client.new url: url
      options = {
        index: CheckElasticSearchModel.get_index_name,
        type: 'media_search',
        body: {
          script: { source: "ctx._source.status = params.status", params: { status: 'undetermined' } },
          query: { term: { status: { value: 'pending' } } }
        }
      }
      client.update_by_query options
    end
  end
end
