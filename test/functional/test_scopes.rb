require 'test_helper'
require 'models'

class ScopesTest < Test::Unit::TestCase
  def setup
    @document = Doc do
      set_collection_name 'users'

      key :first_name, String
      key :last_name, String
      key :age, Integer
      key :date, Date
      
      scope :nunemaker, :last_name => "Nunemaker"
      scope :named, lambda { |filter| { :first_name => filter } }
      scope :oldest_first, :sort => [[ :age, -1 ]]
    end
  end

  context "scoped find" do
    setup do
      @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => 27})
      @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => 28})
      @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => 26})
    end
    
    should "find scoped documents with a dynamic method name" do
      assert_same_elements @document.scoped_by_last_name('Nunemaker'), [ @doc1, @doc3 ]
    end
    
    should "return a scope when called with a dynamic method name" do
      @document.scoped_by_last_name('Nunemaker').all(:age.gt => 26).should == [ @doc1 ]
    end

    should "handle named scopes correctly" do
      assert_same_elements @document.nunemaker, [ @doc1, @doc3 ]
    end
    
    should "handle named scopes with procs correctly" do
      assert_same_elements @document.named(/^Ste/), [ @doc2, @doc3 ]
    end
    
    should "compose scopes correctly" do
      assert_same_elements @document.nunemaker.named("John"), [ @doc1 ]
    end
    
    should "accept scope options for sort" do
      @document.oldest_first.limit(1).should == [ @doc2 ]
    end
  end
  
  context "on associations" do
    setup do
      Project.collection.remove
      Collaborator.collection.remove
      @project = Project.create
      @john = @project.collaborators.create :name => "John"
      @matt = @project.collaborators.create :name => "Matt"
      @other_john = Collaborator.create :name => "John"
      Collaborator.scope :johns, { :name => "John" }
    end

    should "allow dynamic scopes" do
      @project.collaborators.scoped(:name => "John").should == [ @john ]
    end

    should "allow named scopes" do
      @project.collaborators.all.johns.should == [ @john ]
    end
  end
end