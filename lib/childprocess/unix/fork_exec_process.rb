module ChildProcess
  module Unix
    class ForkExecProcess < Process
      private

      def launch_process
        puts "running ChildProcess::Unix::ForkExecProcess.launch_process()"
        if @io
          puts "@io defined"
          stdout = @io.stdout
          puts "done defining stdout"
          stderr = @io.stderr
          puts "done defining stderr"
        end

        puts "calling ::IO.pipe"
        # pipe used to detect exec() failure
        exec_r, exec_w = ::IO.pipe
        puts "calling ChildProcess.close_on_exec"
        ChildProcess.close_on_exec exec_w

        puts "done calling ChildProcess.close_on_exec"

        if duplex?
          puts "duplex? true"
          reader, writer = ::IO.pipe
          puts "done calling ::IO.pipe"
        end

        puts "before we fork let's examine some variables"
        puts "is leader?: #{leader?}"
        puts "@cwd:"
        p @cwd
        puts "arguments to exec:"
        p @args

        puts "Can we fork this process? #{Process.respond_to?(:fork)}"

        puts "forking process"
        @pid = Kernel.fork {
          puts "setting process group to zero if leader"
          puts "is leader?: #{leader?}"
          # Children of the forked process will inherit its process group
          # This is to make sure that all grandchildren dies when this Process instance is killed
          ::Process.setpgid 0, 0 if leader?

          if @cwd
            puts "@cwd defined"
            Dir.chdir(@cwd)
            puts "done changing directory to #{@cwd}"
          end

          puts "calling exec_r.close"
          exec_r.close

          puts "setting environment"
          set_env

          puts "reopening STDOUT"
          STDOUT.reopen(stdout || "/dev/null")
          puts "reopening STDERR"
          STDERR.reopen(stderr || "/dev/null")
          puts "done reopening STDERR"

          if duplex?
            puts "duplex? true"
            STDIN.reopen(reader)
            puts "done reopening STDIN with reader"
            writer.close
            puts "done closing writer"
          end

          puts "assigning some variables from args"
          p @args
          executable, *args = @args

          puts "executing arguments"
          begin
            Kernel.exec([executable, executable], *args)
          rescue SystemCallError => ex
            puts "exec ran into error"
            exec_w << ex.message
          end
        }

        puts "running exec_w.close"
        exec_w.close

        puts "done running exec_w.close"
        if duplex?
          puts "duplex? true"
          io._stdin = writer
          puts "done setting io._stdin"
          reader.close
          puts "done running reader.close"
        end

        # if we don't eventually get EOF, exec() failed
        unless exec_r.eof?
          puts "did not reach EOF"
          raise LaunchError, exec_r.read || "executing command with #{@args.inspect} failed"
        end

        puts "maybe detaching process"
        puts "detach?: #{detach?}"
        ::Process.detach(@pid) if detach?
      end

      def set_env
        @environment.each { |k, v| ENV[k.to_s] = v.nil? ? nil : v.to_s }
      end

    end # Process
  end # Unix
end # ChildProcess
