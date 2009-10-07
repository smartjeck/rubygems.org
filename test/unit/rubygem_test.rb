require File.dirname(__FILE__) + '/../test_helper'

class RubygemTest < ActiveSupport::TestCase
  context "with a saved rubygem" do
    setup do
      @rubygem = Factory(:rubygem, :name => "SomeGem")
    end
    subject { @rubygem }

    should_have_many :owners, :through => :ownerships
    should_have_many :ownerships, :dependent => :destroy
    should_have_many :versions, :dependent => :destroy
    should_have_one :linkset, :dependent => :destroy
    should_validate_uniqueness_of :name
    should_allow_values_for :name, "rails", "awesome42", "factory_girl", "rack-test"
  end

  context "with a rubygem" do
    setup do
      @rubygem = Factory.build(:rubygem)
    end

    %w[1337 Snakes!].each do |bad_name|
      should "not accept #{bad_name} as a name" do
        @rubygem.name = bad_name
        assert ! @rubygem.valid?
      end
    end

    context "with a user" do
      setup do
        @user = Factory(:user)
      end

      context "before being saved" do
        should "be able to assign ownership" do
          @rubygem.build_ownership(@user)
          @rubygem.save
          assert_contains @rubygem.owners, @user
        end
      end

      context "after being saved" do
        setup do
          @new_user = Factory(:user)
          @rubygem.save
        end

        should "be able to assign ownership" do
          @rubygem.build_ownership(@new_user)
          @rubygem.save
          assert_contains @rubygem.owners, @new_user
        end
      end

      context "after being saved with a version" do
        setup do
          @new_user = Factory(:user)
          @rubygem.save
          @rubygem.update_attributes(:versions_count => 1)
        end

        should "not be able to assign ownership" do
          @rubygem.build_ownership(@new_user)
          @rubygem.save
          assert_does_not_contain @rubygem.owners, @new_user
        end
      end
    end

    context "with a user" do
      setup do
        @rubygem.save
        @user = Factory(:user)
      end

      should "be owned by a user in approved ownership" do
        ownership = Factory(:ownership, :user => @user, :rubygem => @rubygem, :approved => true)
        assert @rubygem.owned_by?(@user)
        assert !@rubygem.unowned?
      end

      should "be not owned by a user in unapproved ownership" do
        ownership = Factory(:ownership, :user => @user, :rubygem => @rubygem)
        assert !@rubygem.owned_by?(@user)
        assert @rubygem.unowned?
      end

      should "be not owned by a user without ownership" do
        other_user = Factory(:user)
        ownership = Factory(:ownership, :user => other_user, :rubygem => @rubygem)
        assert !@rubygem.owned_by?(@user)
        assert @rubygem.unowned?
      end

      should "be not owned if no ownerships" do
        assert @rubygem.ownerships.empty?
        assert !@rubygem.owned_by?(@user)
        assert @rubygem.unowned?
      end

      should "be not owned if no user" do
        assert !@rubygem.owned_by?(nil)
        assert @rubygem.unowned?
      end
    end

    context "with subscribed users" do
      setup do
        @subscribed_user   = Factory(:user)
        @unsubscribed_user = Factory(:user)
        Factory(:subscription, :rubygem => @rubygem, :user => @subscribed_user)
      end

      should "only fetch the subscribed users with #subscribers" do
        assert_contains         @rubygem.subscribers, @subscribed_user
        assert_does_not_contain @rubygem.subscribers, @unsubscribed_user
      end
    end

    should "return current version" do
      assert_equal @rubygem.versions.first, @rubygem.versions.latest
    end

    should "return name with version for #to_s" do
      @rubygem.save
      @rubygem.versions.create(:number => "0.0.0")
      assert_equal "#{@rubygem.name} (#{@rubygem.versions.latest})", @rubygem.to_s
    end

    should "return name for #to_s if current version doesn't exist" do
      assert_equal @rubygem.name, @rubygem.to_s
    end

    should "return name with downloads for #with_downloads" do
      assert_equal "#{@rubygem.name} (#{@rubygem.downloads})", @rubygem.with_downloads
    end

    should "return a bunch of json" do
      Factory(:version, :rubygem => @rubygem)
      hash = JSON.parse(@rubygem.to_json)
      assert_equal @rubygem.name, hash["name"]
      assert_equal @rubygem.slug, hash["slug"]
      assert_equal @rubygem.downloads, hash["downloads"]
      assert_equal @rubygem.versions.latest.number, hash["version"]
      assert_equal @rubygem.versions.latest.authors, hash["authors"]
      assert_equal @rubygem.versions.latest.info, hash["info"]
      assert_equal @rubygem.versions.latest.rubyforge_project, hash["rubyforge_project"]
    end
  end

  context "with some rubygems" do
    setup do
      @rubygem_without_version = Factory(:rubygem)
      @rubygem_with_version = Factory(:rubygem)
      @rubygem_with_versions = Factory(:rubygem)

      Factory(:version, :rubygem => @rubygem_with_version)
      3.times { Factory(:version, :rubygem => @rubygem_with_versions) }
    end

    should "return only gems with one version" do
      assert ! Rubygem.with_one_version.include?(@rubygem_without_version)
      assert Rubygem.with_one_version.include?(@rubygem_with_version)
      assert ! Rubygem.with_one_version.include?(@rubygem_with_versions)
    end

    should "return only gems with versions for #with_versions" do
      assert ! Rubygem.with_versions.include?(@rubygem_without_version)
      assert Rubygem.with_versions.include?(@rubygem_with_version)
      assert Rubygem.with_versions.include?(@rubygem_with_versions)
    end

    should "be hosted or not" do
      assert ! @rubygem_without_version.hosted?
      assert @rubygem_with_version.hosted?
    end

    should "return a nil rubyforge project without any versions" do
      assert_nil @rubygem_without_version.rubyforge_project
    end

    should "return the current rubyforge project with a version" do
      assert_equal @rubygem_with_version.versions.latest.rubyforge_project,
                   @rubygem_with_version.rubyforge_project
    end
  end

  context "with a rubygem that has a version with a nil rubyforge_project" do
    setup do
      @rubygem = Factory(:rubygem)
      @rubyforge_project = 'test_project'
      Factory(:version, :rubygem => @rubygem, :rubyforge_project => nil)
      Factory(:version, :rubygem => @rubygem, :rubyforge_project => @rubyforge_project)
    end

    should "return the first non-nil rubyforge_project" do
      assert_equal @rubyforge_project, @rubygem.rubyforge_project
    end
  end

  context "with some gems and some that don't have versions" do
    setup do
      @thin = Factory(:rubygem, :name => 'thin', :created_at => 1.year.ago,  :downloads => 20)
      @rake = Factory(:rubygem, :name => 'rake', :created_at => 1.month.ago, :downloads => 10)
      @json = Factory(:rubygem, :name => 'json', :created_at => 1.week.ago,  :downloads => 5)
      @thor = Factory(:rubygem, :name => 'thor', :created_at => 2.days.ago,  :downloads => 3)
      @rack = Factory(:rubygem, :name => 'rack', :created_at => 1.day.ago,   :downloads => 2)
      @dust = Factory(:rubygem, :name => 'dust', :created_at => 3.days.ago,  :downloads => 1)
      @haml = Factory(:rubygem, :name => 'haml')
      @new = Factory.build(:rubygem)

      @gems = [@thin, @rake, @json, @thor, @rack, @dust]
      @gems.each { |g| Factory(:version, :rubygem => g); g.increment!(:versions_count) }
    end

    should "be pushable if gem is a new record" do
      assert @new.pushable?
    end

    should "be pushable if gem has no versions" do
      assert @haml.pushable?
    end

    should "not be pushable if it has versions" do
      assert ! @thin.pushable?
    end

    should "give a count of only rubygems with versions" do
      assert_equal 6, Rubygem.total_count
    end

    should "only return the latest gems with versions" do
      assert_equal [@rack, @thor, @dust, @json, @rake],        Rubygem.latest
      assert_equal [@rack, @thor, @dust, @json, @rake, @thin], Rubygem.latest(6)
    end

    should "only latest downloaded versions" do
      assert_equal [@thin, @rake, @json, @thor, @rack],        Rubygem.downloaded
      assert_equal [@thin, @rake, @json, @thor, @rack, @dust], Rubygem.downloaded(6)
    end
  end

  context "when some gems exist with titles and versions that have descriptions" do
    setup do
      @apple_pie = Factory(:rubygem, :name => 'apple')
      Factory(:version, :description => 'pie', :rubygem => @apple_pie)

      @orange_julius = Factory(:rubygem, :name => 'orange')
      Factory(:version, :description => 'julius', :rubygem => @orange_julius)
    end

    should "find rubygems by name on #search" do
      assert Rubygem.search('apple').include?(@apple_pie)
      assert Rubygem.search('orange').include?(@orange_julius)

      assert ! Rubygem.search('apple').include?(@orange_julius)
      assert ! Rubygem.search('orange').include?(@apple_pie)
    end

    should "find rubygems by description on #search" do
      assert Rubygem.search('pie').include?(@apple_pie)
      assert Rubygem.search('julius').include?(@orange_julius)

      assert ! Rubygem.search('pie').include?(@orange_julius)
      assert ! Rubygem.search('julius').include?(@apple_pie)
    end

    should "find rubygems case insensitively on #search" do
      assert Rubygem.search('APPLE').include?(@apple_pie)
      assert Rubygem.search('PIE').include?(@apple_pie)
    end
  end

  context "building a new Rubygem" do
    context "from a Gem::Specification with no dependencies" do
      setup do
        @specification = gem_specification_from_gem_fixture('test-0.0.0')
        @rubygem       = Rubygem.create(:name => @specification.name)
        @version       = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_change("total number of Rubygems", :by => 1) { Rubygem.count }
      should_change("total number of Versions", :by => 1) { Version.count }
      should_not_change("total number of Dependencies")   { Dependency.count }

      should "have the homepage set properly" do
        assert_equal @specification.homepage, @rubygem.linkset.home
      end
    end

    context "from a Gem::Specification with dependencies" do
      setup do
        @specification = gem_specification_from_gem_fixture('with_dependencies-0.0.0')
        @rubygem       = Rubygem.create(:name => @specification.name)
        @version       = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_change("total number of Rubygems",     :by => 3) { Rubygem.count }
      should_change("total number of Versions",     :by => 1) { Version.count }
      should_change("total number of Dependencies", :by => 2) { Dependency.count }

      should "create Rubygem instances for the dependencies" do
        assert_not_nil Rubygem.find_by_name('thoughtbot-shoulda')
        assert_not_nil Rubygem.find_by_name('rake')
      end
    end
  end

  context "updating an existing Rubygem" do
    setup do
      @specification = gem_specification_from_gem_fixture('with_dependencies-0.0.0')
      @rubygem       = Rubygem.create(:name => @specification.name)
      @version       = @rubygem.find_or_initialize_version_from_spec(@specification)
      @rubygem.update_attributes_from_gem_specification!(@version, @specification)
    end

    context "from a Gem::Specification" do
      setup do
        @rubygem = Rubygem.find_by_name(@specification.name)
        @version = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_not_change("total number of Rubygems") { Rubygem.count }
      should_not_change("number of Versions")       { @rubygem.versions.count }
      should_not_change("number of Dependencies")   { @rubygem.versions.last.dependencies.count }

      should "have the homepage set properly" do
        assert_equal @specification.homepage, @rubygem.linkset.home
      end
    end

    context "from a Gem::Specification with new details" do
      setup do
        @homepage = 'http://new.example.org'
        @specification.homepage = @homepage
        @rubygem = Rubygem.find_by_name(@specification.name)
        @version = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_not_change("total number of Rubygems") { Rubygem.count }
      should_not_change("number of Versions")       { @rubygem.versions.count }
      should_not_change("number of Dependencies")   { @rubygem.versions.last.dependencies.count }
      should_change("homepage", :to => @homepage)   { @rubygem.linkset.home }
    end

    context "from a Gem::Specification with a new dependency" do
      setup do
        @specification.add_dependency('new-dependency')
        @rubygem = Rubygem.find_by_name(@specification.name)
        @version = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_change("total number of Rubygems", :by => 1) { Rubygem.count }
      should_not_change("number of Versions")             { @rubygem.versions.count }
      should_change("number of Dependencies",   :by => 1) { @rubygem.versions.last.dependencies.count }
    end

    context "from a Gem::Specification with a new version" do
      setup do
        @specification.version = '0.0.1'
        @rubygem = Rubygem.find_by_name(@specification.name)
        @version = @rubygem.find_or_initialize_version_from_spec(@specification)
        @rubygem.update_attributes_from_gem_specification!(@version, @specification)
      end

      should_not_change("total number of Rubygems")           { Rubygem.count }
      should_change("number of Versions",           :by => 1) { @rubygem.versions.count }
      should_change("total number of Dependencies", :by => 2) { Dependency.count }
    end
  end
end
