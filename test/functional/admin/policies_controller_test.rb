require 'test_helper'

class Admin::PoliciesControllerTest < ActionController::TestCase

  setup do
    @user = login_as :policy_writer
  end

  test_controller_is_a Admin::BaseController

  test "new displays policy form" do
    get :new

    assert_select "form#document_new[action='#{admin_policies_path}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[type='submit']"
    end
  end

  test "new form has previewable body" do
    get :new
    assert_select "textarea[name='document[body]'].previewable"
  end

  test 'creating should create a new policy' do
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)
    attributes = attributes_for(:policy)

    post :create, document: attributes.merge(
      ministerial_role_ids: [first_minister.id, second_minister.id]
    )

    policy = Policy.last
    assert_equal attributes[:title], policy.title
    assert_equal attributes[:body], policy.body
    assert_equal [first_minister, second_minister], policy.ministerial_roles
  end

  test 'creating should take the writer to the policy page' do
    post :create, document: attributes_for(:policy)

    assert_redirected_to admin_policy_path(Policy.last)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'creating with invalid data should leave the writer in the policy editor' do
    attributes = attributes_for(:policy)
    post :create, document: attributes.merge(title: '')

    assert_equal attributes[:body], assigns(:document).body, "the valid data should not have been lost"
    assert_template "documents/new"
  end

  test 'creating with invalid data should set an alert in the flash' do
    attributes = attributes_for(:policy)
    post :create, document: attributes.merge(title: '')

    assert_equal 'There are some problems with the document', flash.now[:alert]
  end

  test 'edit displays policy form' do
    policy = create(:policy)

    get :edit, id: policy

    assert_select "form#document_edit[action='#{admin_policy_path(policy)}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[type='submit']"
    end
  end

  test "edit form has previewable body" do
    policy = create(:policy)
    get :edit, id: policy
    assert_select "textarea[name='document[body]'].previewable"
  end

  test 'updating should save modified policy attributes' do
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)

    policy = create(:policy, ministerial_roles: [first_minister])

    put :update, id: policy, document: {
      title: "new-title",
      body: "new-body",
      ministerial_role_ids: [second_minister.id]
    }

    policy.reload
    assert_equal "new-title", policy.title
    assert_equal "new-body", policy.body
    assert_equal [second_minister], policy.ministerial_roles
  end

  test 'updating should remove all ministerial roles if none in params' do
    minister = create(:ministerial_role)

    policy = create(:policy, ministerial_roles: [minister])

    put :update, id: policy, document: {}

    policy.reload
    assert_equal [], policy.ministerial_roles
  end

  test 'updating should take the writer to the policy page' do
    policy = create(:policy)
    put :update, id: policy, document: {title: 'new-title', body: 'new-body'}

    assert_redirected_to admin_policy_path(policy)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'updating records the user who changed the document' do
    policy = create(:policy)
    put :update, id: policy, document: {title: 'new-title', body: 'new-body'}
    assert_equal @user, policy.document_authors(true).last.user
  end

  test 'updating with invalid data should not save the policy' do
    attributes = attributes_for(:policy)
    policy = create(:policy, attributes)
    put :update, id: policy, document: attributes.merge(title: '')

    assert_equal attributes[:title], policy.reload.title
    assert_template "documents/edit"
    assert_equal 'There are some problems with the document', flash.now[:alert]
  end

  test 'updating a stale policy should render edit page with conflicting policy' do
    policy = create(:draft_policy, policy_areas: [build(:policy_area)], organisations: [build(:organisation)], ministerial_roles: [build(:ministerial_role)])
    lock_version = policy.lock_version
    policy.touch

    put :update, id: policy, document: { lock_version: lock_version }

    assert_template 'edit'
    conflicting_policy = policy.reload
    assert_equal conflicting_policy, assigns[:conflicting_document]
    assert_equal conflicting_policy.lock_version, assigns[:document].lock_version
    assert_equal %{This document has been saved since you opened it}, flash[:alert]
  end

  test "cancelling a new policy takes the user to the list of drafts" do
    get :new
    assert_select "a[href=#{admin_documents_path}]", text: /cancel/i, count: 1
  end

  test "cancelling an existing policy takes the user to that policy" do
    draft_policy = create(:draft_policy)
    get :edit, id: draft_policy
    assert_select "a[href=#{admin_policy_path(draft_policy)}]", text: /cancel/i, count: 1
  end

  test 'updating a submitted policy with bad data should show errors' do
    attributes = attributes_for(:submitted_policy)
    submitted_policy = create(:submitted_policy, attributes)
    put :update, id: submitted_policy, document: attributes.merge(title: '')

    assert_template 'edit'
  end

  test "show the 'add supporting page' button for an unpublished document" do
    draft_policy = create(:draft_policy)

    get :show, id: draft_policy

    assert_select "a[href='#{new_admin_document_supporting_page_path(draft_policy)}']"
  end

  test "don't show the 'add supporting page' button for a published policy" do
    published_policy = create(:published_policy)

    get :show, id: published_policy

    refute_select "a[href='#{new_admin_document_supporting_page_path(published_policy)}']"
  end

  test "should render the content using govspeak markup" do
    draft_policy = create(:draft_policy, body: "body-in-govspeak")
    Govspeak::Document.stubs(:to_html).with("body-in-govspeak").returns("body-in-html")

    get :show, id: draft_policy

    assert_select ".body", text: "body-in-html"
  end

  test "show lists supporting pages when there are some" do
    draft_policy = create(:draft_policy)
    first_supporting_page = create(:supporting_page, document: draft_policy)
    second_supporting_page = create(:supporting_page, document: draft_policy)

    get :show, id: draft_policy

    assert_select ".supporting_pages" do
      assert_select_object(first_supporting_page) do
        assert_select "a[href='#{admin_supporting_page_path(first_supporting_page)}'] span.title", text: first_supporting_page.title
      end
      assert_select_object(second_supporting_page) do
        assert_select "a[href='#{admin_supporting_page_path(second_supporting_page)}'] span.title", text: second_supporting_page.title
      end
    end
  end

  test "show lists each document author once" do
    tom = create(:user, name: "Tom")
    dick = create(:user, name: "Dick")
    harry = create(:user, name: "Harry")

    draft_policy = create(:draft_policy, creator: tom)
    draft_policy.edit_as(dick)
    draft_policy.edit_as(harry)
    draft_policy.edit_as(dick)

    get :show, id: draft_policy

    assert_select ".authors", text: "Tom, Dick, and Harry"
  end

  test "doesn't show supporting pages list when empty" do
    draft_policy = create(:draft_policy)

    get :show, id: draft_policy

    refute_select ".supporting_pages .supporting_page"
  end

  should_allow_policy_areas_for :policy
  should_allow_organisations_for :policy

  should_be_rejectable :policy
  should_be_force_publishable :policy
  should_be_able_to_delete_a_document :policy

  should_link_to_public_version_when_published :policy
  should_not_link_to_public_version_when_not_published :policy
end
