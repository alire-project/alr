with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Alire.Index;
with Alire.Origins;

with Alr.Hardcoded;
with Alr.OS_Lib;

with GNAT.OS_Lib;

with Semantic_Versioning;

package body Alr.Native is

   ----------------
   -- Autodetect --
   ----------------

   procedure Autodetect (Force : Boolean := False) is
   begin
      if Force or else not GNAT.OS_Lib.Is_Regular_File (Hardcoded.Native_Package_List) then
         Trace.Info ("Detecting native Ada packages in platform, please wait...");
         OS_Lib.Spawn_And_Redirect (Hardcoded.Native_Package_List,
                                    Hardcoded.Scripts_Apt_Detect);
      end if;
   end Autodetect;

   ------------------
   -- Add_To_Index --
   ------------------

   procedure Add_To_Index is
      use Ada.Text_IO;

      package Semver renames Semantic_Versioning;

      File : File_Type;
   begin
      if GNAT.OS_Lib.Is_Regular_File (Hardcoded.Native_Package_List) then
         Trace.Debug ("Parsing " & Hardcoded.Native_Package_List & " for native packages...");

         Open (File, In_File, Hardcoded.Native_Package_List);

         while not End_Of_File (File) loop
            declare
               Line : constant String := Get_Line (File);

               -- Fields are: package project version [description]

               First_Space  : constant Natural := Ada.Strings.Fixed.Index (Line, " ");
               Second_Space : constant Natural := Ada.Strings.Fixed.Index (Line, " ", First_Space + 1);
               Third_Space  : constant Natural := Ada.Strings.Fixed.Index (Line, " ", Second_Space + 1);
            begin
               if Second_Space > 0 then
                  -- Trace.Debug ("Parsing version " & Line (Second_Space + 1 .. Line'Last));
                  declare
                     Pkg : constant String := Line (Line'First .. First_Space - 1);
                     Prj : constant String := Line (First_Space + 1 .. Second_Space - 1);
                     Ver : constant String := Line (Second_Space + 1 ..
                                                    (if Third_Space > 0 then Third_Space - 1 else Line'Last));
                     Dsc : constant String := (if Third_Space > 0
                                               then Line (Third_Space + 1 .. Line'Last)
                                               else "No description");

                     R : constant Alire.Index.Release := -- Clamp down too long descriptions
                           Alire.Index.Register (Prj,
                                                 Semver.Relaxed (Ver),
                                                 Dsc (Dsc'First .. Dsc'First - 1 + Integer'Min (Alire.Max_Description_Length, Dsc'Length)),
                                                 Alire.Origins.New_Apt (Pkg),
                                                 Native => True) with Unreferenced;
                  begin
                     null;--
                  exception
                     when others =>
                        Trace.Debug ("Exception attempting to index native package:" &
                                       Prj &
                                       " found in package " & Pkg &
                                       " with version " & Ver);
                  end;
               else
                  Trace.Warning ("Bad line in native package list: " & Line);
               end if;
            end;
         end loop;

         Close (File);
      end if;
   end Add_To_Index;

end Alr.Native;
