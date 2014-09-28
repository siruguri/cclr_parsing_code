class RunCommands
  def initialize(opts_hash)
    @_output_fh=nil
    @_fn=Time.now.to_i
    @success=nil

    @opts={}
    if opts_hash
      opts_hash.each do |k,v| 
        @opts[k]=v
      end
    end
  end

  def run_cmd(cmd_string)
    if @opts[:pwd]
      cmd_string = "cd #{@opts[:pwd]}; #{cmd_string}"
    end
    cmd_string += " 2>#{err_filename}"
    @success=nil

    if @_output_fh
      @_output_fh.close
    end

    output = %x[#{cmd_string}]
    @success=$?.success?

    @_output_fh=File.open(out_filename, "w")
    @_output_fh.write(output)

  end

  def has_output(test_re)
    begin
      @_output_fh=File.open(out_filename, "r")
    rescue Errno::ENOENT => e
      return false
    end
    found_re=false
    while !found_re && !@_output_fh.eof
      line = @_output_fh.read
      found_re = line.match test_re
    end
    return found_re
  end

  def close
    if @_output_fh && @_output_fh.respond_to?(:close)
      begin
        @_output_fh.close
      rescue IOError => e
        # Ok to have a closed stream
      end
    end

    if File.exists? out_filename
      File.unlink out_filename
    end

    if File.exists? err_filename
      File.unlink err_filename
    end
  end
  
  def last_cmd_success?
    @success == true
  end

  def last_cmd_has_stderr?
    File.size(err_filename) > 0
  end

  private
  def err_filename
    "_err.#{@_fn}"
  end
  def out_filename
    "_out.#{@_fn}"
  end
end

runner = RunCommands.new(pwd: File.expand_path(File.dirname(__FILE__)))

runner.run_cmd('scripts/generate_group_ids.sh')
runner.run_cmd('scripts/connect_to_db.sh')

runner.close
