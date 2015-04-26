with Ada.Text_IO;
with Types;
with Unchecked_Deallocation;

package body Envs is


   function Is_Null (E : Env_Handle) return Boolean is
      use Smart_Pointers;
   begin
     return Smart_Pointer (E) = Null_Smart_Pointer;
   end Is_Null;


   function New_Env (Outer : Env_Handle) return Env_Handle is
      use Smart_Pointers;
      Level : Natural;
   begin
      if Is_Null (Outer) then
         Level := 0;
      else
         Level := Deref (Outer).Level + 1;
      end if;
      if Debug then
         Ada.Text_IO.Put_Line
           ("Envs: Creating at level " & Natural'Image (Level));
      end if;
      return Env_Handle (Smart_Pointers.New_Ptr (new Env'
               (Base_Class with The_Map => String_Mal_Hash.Empty_Map,
                Outer_Env => Outer,
                Level => Level)));
   end New_Env;


   procedure Set
     (E : Env_Handle;
      Key : String;
      Elem : Smart_Pointers.Smart_Pointer) is
   begin
      if Debug then
         Ada.Text_IO.Put_Line
           ("Envs: Setting " & Key &
            " to " & Types.Deref (Elem).To_String &
            " at level " & Natural'Image (Deref (E).Level));
      end if;
      String_Mal_Hash.Include
        (Container => Deref (E).The_Map,
         Key       => Ada.Strings.Unbounded.To_Unbounded_String (Key),
         New_Item  => Elem);
   end Set;


   function Get (E : Env_Handle; Key: String)
   return Smart_Pointers.Smart_Pointer is

      use String_Mal_Hash;
      C : Cursor;

   begin

      if Debug then
         Ada.Text_IO.Put_Line
           ("Envs: Finding " & Key &
            " at level " & Natural'Image (Deref (E).Level));
      end if;

      C := Find (Deref (E).The_Map,
                 Ada.Strings.Unbounded.To_Unbounded_String (Key));

      if C = No_Element then

         if Is_Null (Deref (E).Outer_Env) then
            raise Not_Found;
         else
            return Get (Deref (E).Outer_Env, Key);
         end if;

      else
         return Element (C);
      end if;

   end Get;


   procedure Set_Outer
     (E : Env_Handle; Outer_Env : Env_Handle) is
   begin
      -- Attempt to avoid making loops.
      if Deref (E).Level /= 0 then
         Deref (E).Outer_Env := Outer_Env;
      end if;
   end Set_Outer;


   function To_String (E : Env_Handle) return String is
      use String_Mal_Hash, Ada.Strings.Unbounded;
      C : Cursor;
      Res : Unbounded_String;
   begin
      C := First (Deref (E).The_Map);
      while C /= No_Element loop
         Append (Res, Key (C) &  " => " & Types.To_String (Types.Deref (Element (C)).all) & ", ");
         C := Next (C);
      end loop;
      return To_String (Res);
   end To_String;


   -- Sym and Exprs are lists.  Bind Sets Keys in Syms to the corresponding
   -- expression in Exprs.
   procedure Bind (E : Env_Handle; Syms, Exprs : Types.List_Mal_Type) is
      use Types;
      S, Expr : List_Mal_Type;
      First_Sym : Atom_Ptr;
   begin
      S := Syms;
      Expr := Exprs;
      while not Is_Null (S) loop
         First_Sym := Deref_Atom (Car (S));
         if First_Sym.Get_Atom = "&" then
            S := Deref_List (Cdr (S)).all;
            First_Sym := Deref_Atom (Car (S));
            Set (E, First_Sym.Get_Atom, New_List_Mal_Type (Expr));
            exit;
         end if;
         Set (E, First_Sym.Get_Atom, Car (Expr));
         S := Deref_List (Cdr (S)).all;
         exit when Is_Null (Expr);
         Expr := Deref_List (Cdr (Expr)).all;
      end loop;
   end Bind;


   procedure New_Env is
   begin
      Current := New_Env (Current);
   end New_Env;


   procedure Free is new Unchecked_Deallocation (Env, Env_Ptr);

   procedure Delete_Env is
   begin
      if Debug then
         Ada.Text_IO.Put_Line ("Deleting env at level " & Natural'Image (Deref (Current).Level));
      end if;
      -- Always leave one Env!
      if not Is_Null (Deref (Current).Outer_Env) then
         Current := Deref (Current).Outer_Env;
         -- The old Current is finalized *if* there are no references to it.
         -- Note closures may refer to the old env.
      end if;
   end Delete_Env;
   

   function Get_Current return Env_Handle is
   begin
      return Current;
   end Get_Current;


   function Deref (SP : Env_Handle) return Env_Ptr is
   begin
      return Env_Ptr (Smart_Pointers.Deref (Smart_Pointers.Smart_Pointer (SP)));
   end Deref;


end Envs;
