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
    end
  end

  context "scoped find" do
    setup do
      @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => 27})
      @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => 28})
      @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => 26})
    end
    
    should "find scoped documents with a dynamic method name" do
      @document.scoped_by_last_name('Nunemaker', :order => 'age DESC').should == [ @doc1, @doc3 ]
    end
    
    should "return a scope when called with a dynamic method name" do
      @document.scoped_by_last_name('Nunemaker').all(:age.gt => 26).should == [ @doc1 ]
    end
  end
end