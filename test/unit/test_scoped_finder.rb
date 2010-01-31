require 'test_helper'
require 'models'

class ScopedFinderTest < Test::Unit::TestCase
  include MongoMapper
  
  context "from #all" do
    should "be the right class" do
      PostComment.all.class.should == ScopedFinder
    end
    
    should "retain options" do
      PostComment.all(:foo => "bar").proxy_options.should == { :foo => "bar", :limit => 0, :fields => nil, :skip => 0, :sort => nil }
    end
    
    should "compose options with scoped" do
      PostComment.all(:foo => "bar").scoped(:baz => "qux").proxy_options.should == 
        { :foo => "bar", :baz => "qux", :limit => 0, :fields => nil, :skip => 0, :sort => nil }
    end
  end
end