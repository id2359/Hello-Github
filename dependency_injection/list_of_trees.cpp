extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
#include "list_of_trees.h"

// This included file was generated by tolua++
// We turn off the write-strings diagnostic
// because otherwise GCC is quite loud about it,
// and we're not going to edit the generated code to fix the warnings
#pragma GCC diagnostic ignored "-Wwrite-strings"
#include "list_of_trees_bind.c"

#include <stdio.h>

class ListPrintVisitor : public ListOfTreesVisitor {
public:
  void Empty() {
    printf("Empty\n");
  }
  void Nonempty(Tree* first, ListOfTrees* rest) {
    printf("Nonempty\n");
    first->Visit(tree_printer);
    rest->Visit(*this);
  }
private:
  class TreePrintVisitor : public TreeVisitor {
  public:
    void Leaf(int value) {
      printf("Leaf: %d\n", value);
    }
    void Branch(Tree* left, Tree* right) {
      printf("Branch\n");
      left->Visit(*this);
      right->Visit(*this);
    }
  } tree_printer;
} list_printer;

int main() {
  lua_State* L= lua_open();
  luaopen_base(L);
  luaopen_io(L);
  luaopen_string(L);
  luaopen_math(L);
  tolua_list_of_trees_open(L);
  
  if (luaL_loadfile(L, "list_of_trees.lua")
      || lua_pcall(L, 0, 0, 0)) // TODO: understand these args better.
    { 
      fprintf(stderr,
	      "cannot run configuration file: %s",
	      lua_tostring(L, -1));
    }

  lua_getglobal(L, "example");
  ListOfTrees* example= *((ListOfTrees**)(lua_touserdata(L, -1)));
  example->Visit(list_printer);

  lua_close(L);
  return 0;
}

