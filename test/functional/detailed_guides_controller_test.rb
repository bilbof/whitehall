require "test_helper"

class DetailedGuidesControllerTest < ActionController::TestCase
  should_be_a_public_facing_controller
  should_display_attachments_for :detailed_guide
  should_show_inapplicable_nations :detailed_guide
  should_be_previewable :detailed_guide
  should_set_slimmer_analytics_headers_for :detailed_guide
  should_set_the_article_id_for_the_edition_for :detailed_guide
  should_not_show_share_links_for :detailed_guide

  view_test "guide <title> contains Detailed guidance" do
    guide = create(:published_detailed_guide)

    get :show, id: guide.document

    assert_select "title", text: /${guide.document.title} | Detailed guidance/
  end

  view_test "shows related organisations" do
    organisation = create(:organisation, name: 'The Organisation')
    guide = create(:published_detailed_guide, organisations: [organisation])

    get :show, id: guide.document

    assert_select "a[href=?]", organisation_path(organisation), text: 'The Organisation'
  end

  view_test "shows link to each section in the document navigation" do
    guide = create(:published_detailed_guide, body: %{
## First Section

Some content

## Another Bit

More content

## Final Part

That's all
})

    get :show, id: guide.document

    assert_select "ol#document_sections" do
      assert_select "li a[href='#first-section']", 'First Section'
      assert_select "li a[href='#another-bit']", 'Another Bit'
      assert_select "li a[href='#final-part']", 'Final Part'
    end
  end

  view_test "show includes any links to related mainstream content" do
    guide = create(:published_detailed_guide,
      related_mainstream_content_url: "http://mainstream/content",
      related_mainstream_content_title: "Some related mainstream content",
      additional_related_mainstream_content_url: "http://mainstream/additional-content",
      additional_related_mainstream_content_title: "Some additional related mainstream content"
    )

    get :show, id: guide.document

    assert_select "a[href='http://mainstream/content']", "Some related mainstream content"
    assert_select "a[href='http://mainstream/additional-content']", "Some additional related mainstream content"
  end

  test "the format name is being set to 'detailed_guidance'" do
    guide = create(:published_detailed_guide)

    get :show, id: guide.document

    assert_equal "detailed_guidance", response.headers["X-Slimmer-Format"]
  end

  private

  def given_two_detailed_guides_in_two_organisations
    @organisation_1, @organisation_2 = create(:organisation), create(:organisation)
    @detailed_guide_in_organisation_1 = create(:published_detailed_guide, organisations: [@organisation_1])
    @detailed_guide_in_organisation_2 = create(:published_detailed_guide, organisations: [@organisation_2])
  end

  def given_two_detailed_guides_in_two_policy_areas
    @policy_area_1, @policy_area_2 = create(:topic), create(:topic)
    @published_detailed_guide, @published_in_second_policy_area = create_detailed_guides_in(@policy_area_1, @policy_area_2)
  end

  def create_detailed_guides_in(*policy_areas)
    policy_areas.map do |policy_area|
      create(:published_detailed_guide, topics: [policy_area])
    end
  end
end
