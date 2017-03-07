module Timetrap
# Add any bootup procedures you need here (ie: pre-run configs etc)
# @author psyomn
class Boot 
  
  def run
    make_timetrap_directory!
  end

  private

  def make_timetrap_directory!
    unless File.exists? Config::TIMETRAP_DIR
      require 'fileutils'
      FileUtils.mkdir_p Config::TIMETRAP_DIR
    end
  end

end
end # module Timetrap
