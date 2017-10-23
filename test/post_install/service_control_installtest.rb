#
# service_control_installtest.rb
#
gem "minitest"
require 'minitest/autorun'
require 'minitest/spec'

REGEX_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

=begin
    NOTES:
    First irregularity I encountered was that start requires sleeps sometimes both at initialization,
    and in the tests, to assure it always passes. Given that, and the helpful feature (careful never
    to denigrate this, as it does help you) of minitest always running the tests in a different order
    between iterations, I strongly recommend any draft changes in this test suite be followed by a
    multiple run loop execution for instance as follows:

        for i in 1 2 3 4 5; do sudo ./service_control_installedtest.rb ; echo "result $?"; date; done

    to make sure a healthy number of state combinations are covered.  This is a recommendation for a
    finalization exercise in a sequence, of course, and is not necessary during the increments of
    your development activities when you are trying to get each new stepped validated.

xc
=end

describe "service_control POSIX shell utility in OMS installer scripts area." do
    after do
        lr = `/opt/microsoft/omsagent/bin/service_control enable 2>&1`
        lr = `/opt/microsoft/omsagent/bin/service_control stop 2>&1`
        @StopState_FromAfter = 0
        lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
        @StopState_FromAfter += $?.exitstatus
        lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
        @StopState_FromAfter += $?.exitstatus
        lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
        @StopState_FromAfter += $?.exitstatus
    end
    before do
        @omsadminlresult = `/opt/microsoft/omsagent/bin/omsadmin.sh -l`
        @workspaceids = Array.new
        @omsadminlresult.each_line do |l|
            l =~ /(#{REGEX_UUID})/
            @workspaceids.push($1) 
        end
        unless @workspaceids.length >= 3
            STDERR.puts "ERROR:  There should be three workspace ids; #{@workspaceids.length} found."
            exit 99
        end
	sleep @workspaceids.length
        lr = `/opt/microsoft/omsagent/bin/service_control start 2>&1`
        @StartState_FromBefore = 0
        lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
        @StartState_FromBefore += $?.exitstatus
        lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
        @StartState_FromBefore += $?.exitstatus
        lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
        @StartState_FromBefore += $?.exitstatus
    end
    describe "No Arguments" do
        it "Provides messaging indicating unfunctional call." do
            lr = `/opt/microsoft/omsagent/bin/service_control 2>&1`
            lr.must_match /Unknown parameter :/
        end
    end
    describe "disable" do
        it "Disabled works from running state." do
            @StartState_FromBefore.must_equal 0

            lr = `/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr.must_match /INFO:  Unconfiguring OMS agent.*?#{@workspaceids[0]}/
            lr = `. ./oms_standard_validation_library.sh; validate_disable_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Disabled works from stopped state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr.must_match /INFO:  Unconfiguring OMS agent.*?#{@workspaceids[0]}/
            lr = `. ./oms_standard_validation_library.sh; validate_disable_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "You can disable two of three workspaces and then re-enable them with start." do
            @StartState_FromBefore.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr.must_match /INFO:  Unconfiguring OMS agent.*?#{@workspaceids[1]}/
            lr = `. ./oms_standard_validation_library.sh; validate_disable_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
            lr.must_match /INFO:  Unconfiguring OMS agent.*?#{@workspaceids[2]}/
            lr = `. ./oms_standard_validation_library.sh; validate_disable_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control enable #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "You can disable and re-enable a workspace multiple times without having effects on the other two." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_disable_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control enable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control enable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "enable" do
        it "Enabled state validations work from the enabled state." do
            @StartState_FromBefore.must_equal 0

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Multiple workspace activities always result in reasonable enabled states." do
            @StartState_FromBefore.must_equal 0

            i=0
            3.times do
                
                lr=`/opt/microsoft/omsagent/bin/service_control stop #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control enable #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control stop #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control enable #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[i]} 2>&1`
                $?.exitstatus.must_equal 0

                i += 1
            end

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "find-systemd-dir" do
        it "Displays the directory of the systemd daemon when the OS has it." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control find-systemd-dir 2>&1`
            if $?.exitstatus == 0 then
                lr.must_match /\/.*\/.*system.*\//
                lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
                $?.exitstatus.must_equal 0 
            end
        end
    end
=begin
# Skipping this for now as low priority for first draft.
    describe "functions" do
        it "Allows script to be treated as a library using the source or dot command. " do
        end
    end
=end
    describe "is-running" do
        #### NOTE:  As per various conversations in the project, returning 1 for boolean TRUE
        #### is excessively confusing in script languages.  Far better to echo back string "1"
        #### over stdout if such a value is needed, as the context of scripting is that zero
        #### is always true or success, and everything else is false or failure.  This, however
        #### would require extensive testing to make sure a fix does not break anything I fear.
        #### XC
        it "Returns 1 if the omsagent is running." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control is-running 2>&1`
            $?.exitstatus.must_equal 1

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 1

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 1

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 1
        end
        it "Returns 0 if the omsagent is NOT running." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control is-running 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control is-running #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "reload" do
        it "Re-Load does a restart. (must add more tests when reload is refactored to do something else)" do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control reload 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Re-Load should work with a single workspace specified." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control reload #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "restart" do
        it "Re-start the oms agent so it re-reads it's configurations and comes back up in a healthy state, passing all running state validations." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control restart 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Re-start should work from an already started state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control restart #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Re-start should work from an stopped state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control restart #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Re-start should work from an disabled state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr=`/opt/microsoft/omsagent/bin/service_control restart #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "start" do
        it "Start the oms agent so it re-reads it's configurations and comes back up in a healthy state, passing all running state validations." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop 2>&1`
            $?.exitstatus.must_equal 0 

            lr=`/opt/microsoft/omsagent/bin/service_control start 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Start should work from on an individual workspace." do
            lr=`/opt/microsoft/omsagent/bin/service_control stop 2>&1`
            $?.exitstatus.must_equal 0 

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0 
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 
            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Start should work from an disabled state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr=`/opt/microsoft/omsagent/bin/service_control start #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control disable 2>&1`
            $?.exitstatus.must_equal 0 

            lr=`/opt/microsoft/omsagent/bin/service_control start 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
    describe "stop" do
        it "Stop the oms agent for all workspaces from a running state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
        it "Stop the oms agent for a single workspace from a running state." do
            @StartState_FromBefore.must_equal 0

            lr=`/opt/microsoft/omsagent/bin/service_control stop #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0 

            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_primary_workspace_state_healthy_onboarded #{@workspaceids[0]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_stop_state_healthy_onboarded #{@workspaceids[1]} 2>&1`
            $?.exitstatus.must_equal 0
            lr = `. ./oms_standard_validation_library.sh; validate_running_state_healthy_onboarded #{@workspaceids[2]} 2>&1`
            $?.exitstatus.must_equal 0
        end
    end
end
#
# End of service_control_installtest.rb
