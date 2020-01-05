# frozen_string_literal: true

RSpec.describe Bitly::API::Bitlink do
  let(:client) { double("client") }
  let(:bitlink_data) {
    {
      "created_at"=>"2020-01-02T23:51:47+0000",
      "id"=>"bit.ly/2Qj2niP",
      "link"=>"http://bit.ly/2Qj2niP",
      "custom_bitlinks"=>[],
      "long_url"=>"https://example.com/",
      "archived"=>false,
      "tags"=>[],
      "deeplinks"=>[],
      "references"=>{
        "group"=>"https://api-ssl.bitly.com/v4/groups/def456"
      }
    }
  }
  let(:public_bitlink_data) {
    {
      "created_at"=>"2020-01-02T23:51:47+0000",
      "link"=>"http://bit.ly/2Qj2niP",
      "id"=>"bit.ly/2Qj2niP",
      "long_url"=>"https://example.com/"
    }
  }

  it "can shorten a link with an API client" do
    response = Bitly::HTTP::Response.new(
      status: "200",
      body: bitlink_data.to_json,
      headers: {}
    )
    expect(client).to receive(:request)
      .with(
        path: "/shorten",
        method: "POST",
        params: { "long_url" => "https://example.com/", "group_guid" => nil, "domain" => nil }
      )
      .and_return(response)
    bitlink = Bitly::API::Bitlink.shorten(client: client, long_url: "https://example.com/")
    expect(bitlink.long_url).to eq("https://example.com/")
    expect(bitlink.id).to eq("bit.ly/2Qj2niP")
  end

  it "can create a bitlink with more details" do
    extra_bitlink_data = bitlink_data.clone
    extra_bitlink_data["title"] = "Test link"
    extra_bitlink_data["deeplinks"] = [{
      "app_uri_path" => "test_app_uri_path",
      "install_type" => "test_install_type",
      "install_url" =>	"test_install_url",
      "app_id" => "test_app_id"
    }]
    deeplink = Bitly::API::Bitlink::Deeplink.new(data: {
      "app_uri_path" => "test_app_uri_path",
      "install_type" => "test_install_type",
      "install_url" =>	"test_install_url",
      "app_id" => "test_app_id"
    })
    response = Bitly::HTTP::Response.new(
      status: "200",
      body: extra_bitlink_data.to_json,
      headers: {}
    )
    expect(client).to receive(:request)
      .with(
        path: "/bitlinks",
        method: "POST",
        params: {
          "long_url" => "https://example.com/",
          "group_guid" => nil,
          "domain" => nil,
          "title" => "Test link",
          "tags" => nil,
          "deeplinks" => [deeplink]
        }
      )
      .and_return(response)
    bitlink = Bitly::API::Bitlink.create(
      client: client,
      long_url: "https://example.com/",
      title: "Test link",
      deeplinks: [deeplink]
    )
    expect(bitlink.long_url).to eq("https://example.com/")
    expect(bitlink.id).to eq("bit.ly/2Qj2niP")
    expect(bitlink.title).to eq("Test link")
    expect(bitlink.deeplinks.first).to be_instance_of(Bitly::API::Bitlink::Deeplink)
    expect(bitlink.deeplinks.first.app_uri_path).to eq(deeplink.app_uri_path)
  end

  it "can fetch a bitlink" do
    response = Bitly::HTTP::Response.new(
      status: "200",
      body: bitlink_data.to_json,
      headers: {}
    )
    expect(client).to receive(:request)
      .with(path: "/bitlinks/#{bitlink_data["id"]}")
      .and_return(response)
    bitlink = Bitly::API::Bitlink.fetch(client: client, bitlink: "bit.ly/2Qj2niP")
    expect(bitlink.long_url).to eq("https://example.com/")
  end

  it "can expand a bitlink to public information" do
    response = Bitly::HTTP::Response.new(
      status: "200",
      body: public_bitlink_data.to_json,
      headers: {}
    )
    expect(client).to receive(:request)
      .with(path: "/expand", method: "POST", params: { "bitlink_id" => "bit.ly/2Qj2niP" })
      .and_return(response)
    bitlink = Bitly::API::Bitlink.expand(client: client, bitlink: "bit.ly/2Qj2niP")
    expect(bitlink.long_url).to eq("https://example.com/")
    expect(bitlink.id).to eq("bit.ly/2Qj2niP")
    expect(bitlink.link).to eq("http://bit.ly/2Qj2niP")
    expect(bitlink.created_at).to eq(Time.parse(public_bitlink_data["created_at"]))
  end

  describe Bitly::API::Bitlink::List do
    let(:pagination) {
      {
        "next" => "https://api-ssl.bit.ly/v4/groups/def456/bitlinks?page=2",
        "prev" => "",
        "total" => 100,
        "page" => 1,
        "size" => 50
      }
    }

    it "initializes with pagination data" do
      response = Bitly::HTTP::Response.new(
        status: "200",
        body: { "pagination" => pagination, "links" => [bitlink_data] }.to_json,
        headers: {}
      )
      expect(client).to receive(:request)
        .with(path: "/groups/def456/bitlinks")
        .and_return(response)
      list = Bitly::API::Bitlink.list(client: client, group_guid: "def456")
      expect(list).to be_instance_of(Bitly::API::Bitlink::List)
      expect(list.next_url).to eq(pagination["next"])
      expect(list.prev_url).to eq(pagination["prev"])
      expect(list.total).to eq(pagination["total"])
      expect(list.size).to eq(pagination["size"])
      expect(list.page).to eq(pagination["page"])
    end

    describe "with a bitlink list" do
      let(:list) do
        response = Bitly::HTTP::Response.new(
          status: "200",
          body: { "pagination" => pagination, "links" => [bitlink_data] }.to_json,
          headers: {}
        )
        Bitly::API::Bitlink::List.new(
          client: client,
          response: response,
          items: [Bitly::API::Bitlink.new(data: bitlink_data, client: client)]
        )
      end

      it "has a next page" do
        expect(list.has_next_page?).to be true
      end

      it "doesn't have a previous page" do
        expect(list.has_prev_page?).to be false
      end

      it "can fetch the next page from the list" do
        response = Bitly::HTTP::Response.new(
          status: "200",
          body: { "pagination" => pagination, "links" => [bitlink_data] }.to_json,
          headers: {}
        )
        expect(client).to receive(:request)
          .with(path: "/groups/def456/bitlinks", params: { "page" => ["2"] })
          .and_return(response)
        new_list = list.next_page
        expect(new_list).to be_instance_of(Bitly::API::Bitlink::List)
      end

      it "can't fetch if there is no prev page" do
        expect(list.prev_page).to be nil
      end
    end

  end
end