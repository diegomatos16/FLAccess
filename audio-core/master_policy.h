#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace flaccess {
struct MasterLevel { float volume=1.0f; bool muted=false; };
inline bool belongs_to_game(std::uint32_t owner, std::uint32_t game) noexcept {
    return owner != 0 && owner == game;
}
inline bool valid_level(float value) noexcept {
    return std::isfinite(value) && value >= 0.0f && value <= 1.0f;
}
inline MasterLevel inherit_level(MasterLevel current, MasterLevel source, bool first) noexcept {
    if (first) return source;
    return {std::min(current.volume,source.volume),current.muted || source.muted};
}
inline bool should_forward(std::uint32_t owner, std::uint32_t game, bool own_event, float value) noexcept {
    return belongs_to_game(owner,game) && !own_event && valid_level(value);
}
inline bool level_differs(MasterLevel a, MasterLevel b) noexcept {
    return std::fabs(a.volume-b.volume)>0.00001f || a.muted!=b.muted;
}
}
