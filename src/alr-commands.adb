with Ada.Command_Line;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Text_IO; use Ada.Text_IO;

with Alire;
with Alire_Early_Elaboration;

with Alr.Checkout;
with Alr.Commands.Build;
with Alr.Commands.Clean;
with Alr.Commands.Compile;
with Alr.Commands.Dev;
with Alr.Commands.Get;
with Alr.Commands.Init;
with Alr.Commands.Pin;
with Alr.Commands.Reserved;
with Alr.Commands.Run;
with Alr.Commands.Search;
with Alr.Commands.Update;
with Alr.Commands.Version;
with Alr.Devel;
with Alr.Hardcoded;
with Alr.Native;
with Alr.OS;
with Alr.Utils;

with GNAT.OS_Lib;

package body Alr.Commands is

   use GNAT.Command_Line;

   --  To add a command: update the dispatch table below

   Dispatch_Table : constant array (Cmd_Names) of access Command'Class :=
                      (Cmd_Build    => new Build.Command,
                       Cmd_Clean    => new Clean.Command,
                       Cmd_Compile  => new Compile.Command,
                       Cmd_Dev      => new Dev.Command,
                       Cmd_Get      => new Get.Command,
                       Cmd_Init     => new Init.Command,
                       Cmd_Pin      => new Pin.Command,
                       Cmd_Run      => new Run.Command,
                       Cmd_Search   => new Search.Command,
                       Cmd_Update   => new Update.Command,
                       Cmd_Version  => new Version.Command,
                       others       => new Reserved.Command);

   Log_Quiet  : Boolean renames Alire_Early_Elaboration.Switch_Q;
   Log_Detail : Boolean renames Alire_Early_Elaboration.Switch_V;
   Log_Debug  : Boolean renames Alire_Early_Elaboration.Switch_D;

   Help_Switch : aliased Boolean := False;

   -----------
   -- Image --
   -----------

   function Image (N : Cmd_Names) return String is
      Pre : constant String := To_Lower (N'Img);
   begin
      return Pre (Pre'First + 4 .. Pre'Last);
   end Image;

   --------------
   -- Is_Quiet --
   --------------

   function Is_Quiet return Boolean is (Log_Quiet);

   -------------------------
   -- Set_Global_Switches --
   -------------------------

   procedure Set_Global_Switches (Config : in out GNAT.Command_Line.Command_Line_Configuration) is
   begin
      Define_Switch (Config,
                     Help_Switch'Access,
                     "-h", "--help", "Display general or command-specific help");
      Define_Switch (Config,
                     Use_Native'Access,
                     "-n", "--use-native", "Use autodetected native packages in dependency resolution");
      Define_Switch (Config,
                     Log_Quiet'Access,
                     "-q",
                     Help => "Limit output to errors");
      Define_Switch (Config,
                     Log_Detail'Access,
                     "-v",
                     Help => "Be more verbose");

      Define_Switch (Config,
                     Log_Debug'Access,
                     "-d",
                     Help => "Be even more verbose (including debug messages)");
   end Set_Global_Switches;

   ---------------------
   -- Global_Switches --
   ---------------------

   function Global_Switches return String is
   begin
      return Utils.Trim ((if Log_Debug  then "-d " else "") &
                         (if Log_Detail then "-v " else "") &
                         (if Log_Quiet  then "-q " else ""));
   end Global_Switches;

   ---------------------------
   -- Check_If_Command_Help --
   ---------------------------

   procedure Check_If_Command_Help (Cmd : Cmd_Names) is
      Help_Requested : Boolean := False;
   begin
      Initialize_Option_Scan;
      loop
         case Getopt ("* h") is
            when ASCII.NUL => exit;
            when 'h' => Help_Requested := True;
            when others => null;
         end case;
      end loop;

      if Help_Requested then
         Display_Usage (Cmd);
         OS_Lib.Bailout (0);
      end if;
   end Check_If_Command_Help;

   --------------------------
   -- Create_Alire_Folders --
   --------------------------

   procedure Create_Alire_Folders is
   begin
      OS.Create_Folder (OS.Config_Folder);
      OS.Create_Folder (OS.Cache_Folder);
      OS.Create_Folder (OS.Projects_Folder);
   end Create_Alire_Folders;

   -------------------
   -- Display_Usage --
   -------------------

   procedure Display_Usage is
   begin
      New_Line;
      Put_Line ("Ada Library Repository manager (alr)");
      Put_Line ("Usage : alr command [switches] [arguments]");

      New_Line;

      Display_Valid_Commands;

      New_Line;
      Put_Line ("Use ""alr <command> -h"" for more information about a command.");
      New_Line;
   end Display_Usage;

   -------------------
   -- Display_Usage --
   -------------------

   procedure Display_Usage (Cmd : Cmd_Names) is
      Config  : Command_Line_Configuration;
      Canary1 : Command_Line_Configuration;
      Canary2 : Command_Line_Configuration;
   begin
      Set_Usage (Config,
                 Image (Cmd) & " [options] " & Dispatch_Table (Cmd).Usage_Custom_Parameters,
                 Help => " ");

      -- Ugly hack that goes by GNAT
      Define_Switch (Config, "Global options:", "", "", "", "");
      Define_Switch (Config, " ");
      Set_Global_Switches (Config);

      Set_Global_Switches (Canary1); -- For comparison
      Set_Global_Switches (Canary2); -- For comparison
      Dispatch_Table (Cmd).Setup_Switches (Canary1);

      if Get_Switches (Canary1) /= Get_Switches (Canary2) then
         -- Ugly hack that goes by GNAT
         Define_Switch (Config, " ");
         Define_Switch (Config, "Options specific to " & Image (Cmd) & ":", "", "", "", "");
         Define_Switch (Config, " ");

         Dispatch_Table (Cmd).Setup_Switches (Config);
      end if;

      GNAT.Command_Line.Display_Help (Config);

      Dispatch_Table (Cmd).Display_Help_Details;

      New_Line;
   end Display_Usage;

   ------------------
   -- Longest_Name --
   ------------------

   function Longest_Name return Positive is
   begin
      return Max : Positive := 1 do
         for Cmd in Cmd_Names'Range loop
            Max := Positive'Max (Max, Image (Cmd)'Length);
         end loop;
      end return;
   end Longest_Name;

   ----------------------------
   -- Display_Valid_Commands --
   ----------------------------

   procedure Display_Valid_Commands is
      Tab : constant String (1 .. 8) := (others => ' ');
      Max : constant Positive := Longest_Name + 1;
      Pad : String (1 .. Max);
   begin
      Put_Line ("Valid commands: ");
      New_Line;
      for Cmd in Cmd_Names'Range loop
         if Cmd /= Cmd_Dev or else Alr.Devel.Enabled then
            Put (Tab);

            Pad := (others => ' ');
            Pad (Pad'First .. Pad'First + Image (Cmd)'Length - 1) := Image (Cmd);
            Put (Pad);

            Put (Dispatch_Table (Cmd).Short_Description);
            New_Line;
         end if;
      end loop;
   end Display_Valid_Commands;

   --------------------------
   -- Enter_Project_Folder --
   --------------------------

   function Enter_Project_Folder return Folder_Guard is
   begin
      if Project.Current.Is_Empty then
         Log ("Not entering project folder, no valid project", Debug);
         return OS_Lib.Stay_In_Current_Folder;
      elsif not Bootstrap.Running_In_Session or else not Bootstrap.Session_Is_Current then
         Trace.Debug ("Not entering project folder, outdated session");
         return OS_Lib.Stay_In_Current_Folder;
      else
         return Project.Enter_Root;
      end if;
   end Enter_Project_Folder;

   ------------------------
   -- Requires_Buildfile --
   ------------------------

   procedure Requires_Buildfile is
      Guard : constant OS_Lib.Folder_Guard := Project.Enter_Root with Unreferenced;
   begin
      if not GNAT.OS_Lib.Is_Regular_File (Hardcoded.Build_File (Project.Current.Element.Project)) then
         Checkout.Generate_GPR_Builder (Project.Current.Element);
      end if;
   end Requires_Buildfile;

   ---------------------------
   -- Requires_No_Bootstrap --
   ---------------------------

   procedure Requires_No_Bootstrap is
   begin
      if Bootstrap.Is_Bootstrap then
         Trace.Detail ("Rebuilding catalog...");
         Bootstrap.Rebuild_With_Current_Project;
         Bootstrap.Check_If_Rolling_And_Respawn;
      end if;
   end Requires_No_Bootstrap;

   ----------------------
   -- Requires_Project --
   ----------------------

   procedure Requires_Project is
   begin
      Bootstrap.Check_Rebuild_Respawn; -- Might respawn and not return
      Project.Check_Valid;             -- Might raise Command_Failed
   end Requires_Project;

   -------------
   -- Execute --
   -------------

   procedure Execute is
      use Ada.Command_Line;

      Cmd   : Cmd_Names;
      Pos : Natural;
   begin
      if Argument_Count < 1 or else Argument (1) = "-h" or else Argument (1) = "--help" then
         Display_Usage;
         return;
      else
         Pos := 1; -- Points to first possible command argument
         loop
            exit when Pos > Argument_Count or else
              (Argument (Pos) (Argument (Pos)'first)) /= '-';
            Pos := Pos + 1;
         end loop;

         if Pos > Argument_Count then
            Log ("No command given", Error);
            Display_Usage;
            return;
         end if;

         begin
            Cmd := Cmd_Names'Value ("cmd_" & Argument (Pos));
         exception
            when Constraint_Error =>
               Log ("Unrecognized command: " & Argument (Pos), Error);
               New_Line;
               Display_Usage;
               OS_Lib.Bailout (Pos);
         end;

         Create_Alire_Folders;

         begin
            Execute_By_Name (Cmd);
            Log ("alr " & Argument (Pos) & " done", Detail);
         exception
            when Child_Failed | Command_Failed =>
               Log ("alr " & Argument (Pos) & " unsuccessful", Warning);
               if Alire.Log_Level = Debug then
                  raise;
               else
                  OS_Lib.Bailout (1);
               end if;
         end;
      end if;
   end Execute;

   ---------------------
   -- Execute_Command --
   ---------------------

   procedure Execute_By_Name (Cmd : Cmd_Names) is
      Global_Config, Command_Config, Config : Command_Line_Configuration;
   begin
      Set_Global_Switches (Config);
      Set_Global_Switches (Global_Config);

      Dispatch_Table (Cmd).Setup_Switches (Config);
      Dispatch_Table (Cmd).Setup_Switches (Command_Config);

      --  We do a pre-look for -h to avoid the pre-defined output of procedure Getopt
      Check_If_Command_Help (Cmd); -- Might not return

      begin
         Initialize_Option_Scan;
         Getopt (Config); -- Parses command line switches

         if Use_Native then
            Trace.Detail ("Native packages enabled.");
            Native.Autodetect;
            Native.Add_To_Index;
         end if;

         Log (Image (Cmd) & ":", Detail);
         Dispatch_Table (Cmd).Execute;
      exception
         when Exit_From_Command_Line | Invalid_Switch | Invalid_Parameter =>
            --  Getopt has already displayed some help
            OS_Lib.Bailout (1);

         when Wrong_Command_Arguments =>
            Display_Usage (Cmd);
            OS_Lib.Bailout (1);
      end;
   end Execute_By_Name;

   ------------------------------
   -- Last_Non_Switch_Argument --
   ------------------------------

   function Last_Non_Switch_Argument return String is
      use Ada.Command_Line;
      First, Second : Natural := 0; -- Positions of first and second non-switch arguments

      function Is_Switch (S : String) return Boolean is (S'Length /= 0 and then S (S'First) = '-');
   begin
      if Argument_Count < 2 then
         raise Wrong_Command_Arguments;
      else
         for I in 1 .. Argument_Count loop
            if not Is_Switch (Argument (I)) then
               if First = 0 then
                  First := I;
               elsif Second = 0 then
                  Second := I;
               else
                  --  Too many arguments
                  raise Wrong_Command_Arguments with "At least 3 non-switch arguments found";
               end if;
            end if;
         end loop;

         if Second > 0 then
            return Argument (Second);
         else
            raise Wrong_Command_Arguments with "Missing 2nd non-switch argument";
         end if;
      end if;
   end Last_Non_Switch_Argument;

end Alr.Commands;
