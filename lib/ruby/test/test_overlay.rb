require File.dirname(__FILE__) + '/test_helper.rb'


class TestOverlay < Test::Unit::TestCase

  def setup
    puts "loading repos from #{File::expand_path(File::join(::File::dirname(__FILE__),'resources','overlays'))}"
    Alces::Stack::Overlay::RepoManager::instance.add_repo(::File::expand_path(::File::join(::File::dirname(__FILE__),'resources/overlays')))    
    @repo=Alces::Stack::Overlay::RepoManager::instance.repo(Alces::Stack::Overlay::RepoManager::instance.repo_names.first)
  end

  def test_1
    assert !@repo.nil?
    
    puts @repo.inspect
    
    overlay=@repo.overlay('test_overlay_1')
    
    assert !overlay.nil?
    
    assert @repo.base_path =~ /\/test\/resources\/overlays$/
    
    assert @repo.overlays.size == 1
    
    assert @repo.overlays.first.name == "test_overlay_1"
   
    puts overlay.scriptset.pre_scripts.map { |x| puts x.inspect }
    
    puts overlay.skeleton.files.map { |x| puts x.inspect }
    
    puts overlay.scriptset.post_scripts.map { |x| puts x.inspect }
    
  end
end
