#include "master_policy.h"
#include <cassert>
#include <limits>
#include <iostream>
int main() {
    using namespace flaccess;
    assert(belongs_to_game(42,42));assert(!belongs_to_game(43,42));assert(!belongs_to_game(0,42));
    assert(should_forward(42,42,false,0.4f));assert(!should_forward(42,42,true,0.4f));
    assert(!should_forward(43,42,false,0.4f));assert(!should_forward(42,42,false,-1));
    assert(!should_forward(42,42,false,std::numeric_limits<float>::quiet_NaN()));
    auto value=inherit_level({1,false},{0.3f,false},true);assert(value.volume==0.3f && !value.muted);
    value=inherit_level(value,{0.7f,true},false);assert(value.volume==0.3f && value.muted);
    value=inherit_level({1,false},{0,false},true);assert(value.volume==0 && !value.muted);
    assert(!level_differs({0.5f,false},{0.5f,false})); // No square/multiplication of app volume.
    assert(level_differs({0.5f,false},{0.5f,true}));
    assert(level_differs({0.2f,false},{0.5f,false}));
    std::cout << "PASS 14 master-policy contracts; no Windows sessions opened or modified\n";
}
