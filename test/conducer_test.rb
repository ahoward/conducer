Testing Conducer do
  testing 'that conducers have a root' do
    assert{ Conducer.respond_to?(:root) }
    assert{ Conducer.root }
    assert{ Conducer.root? }
  end

  testing 'that conducers can build a mock controller' do
    controller = assert{ Conducer.mock_controller }
    assert{ controller.url_for '/' }
  end

  testing 'that conducers can mark the current_controller' do
    assert{ Conducer.current_controller = Conducer.mock_controller }
  end

  testing 'that conducers can pre-process parameters' do
    params = Map.new( 
      'conducer' => {
        'foos' => {
          'k' => 'v',
          'array.0' => '0',
          'array.1' => '1'
        },

        'bars' => {
          'a' => 'b',
          'hash.k' => 'v'
        }
      }
    )

    assert{ Conducer.normalize_parameters(params) }
    assert{ params[:conducer] = :normalized }

    assert{ params[:foos].is_a?(Hash) }
    assert{ params[:foos][:k] == 'v' }
    assert{ params[:foos][:array] == %w( 0 1 ) }

    assert{ params[:bars].is_a?(Hash) }
    assert{ params[:bars][:a] == 'b' }
    assert{ params[:bars][:hash] == {'k' => 'v'} }
  end
end


BEGIN {
  testdir = File.dirname(File.expand_path(__FILE__))
  rootdir = File.dirname(testdir)
  libdir = File.join(rootdir, 'lib')
  require File.join(libdir, 'conducer')
  require File.join(testdir, 'testing')
}
