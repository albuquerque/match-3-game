"""
Simple Python test harness that mirrors the StarRatingManager.calculate_stars logic
and verifies expected outputs for typical cases.
Run: python3 tools/test_star_rating.py
"""

def calculate_stars(score: int, target_score: int, moves_used: int, total_moves: int) -> int:
    if score < target_score:
        return 0

    # 3 stars criteria
    if score >= target_score * 2.0:
        return 3

    if moves_used <= total_moves * 0.5:
        return 3

    # 2 stars criteria
    if score >= target_score * 1.5:
        return 2

    # 1 star - completed the level
    return 1


# Test cases derived from STAR_RATING_SYSTEM.md
TESTS = [
    # (score, target, moves_used, total_moves, expected)
    (9000, 10000, 10, 20, 0),       # failed
    (10000, 10000, 20, 20, 1),      # exact target -> 1 star
    (15000, 10000, 20, 20, 2),      # 150% -> 2 stars
    (20000, 10000, 20, 20, 3),      # 200% -> 3 stars
    (13000, 10000, 8, 20, 3),       # used <=50% moves -> 3 stars
    (16000, 10000, 9, 20, 2),       # 160% -> 2 stars
    (18000, 10000, 10, 20, 2),      # 180% -> 2 stars (moves not efficient enough)
    (21000, 10000, 15, 20, 3),      # >200% -> 3
]


def run_tests():
    passed = 0
    for i, (score, target, moves_used, total_moves, expected) in enumerate(TESTS, 1):
        got = calculate_stars(score, target, moves_used, total_moves)
        ok = got == expected
        status = "PASS" if ok else "FAIL"
        print(f"Test {i}: score={score}, target={target}, moves_used={moves_used}/{total_moves} -> expected={expected}, got={got} [{status}]")
        if ok:
            passed += 1

    print(f"\n{passed}/{len(TESTS)} tests passed.")


if __name__ == '__main__':
    run_tests()
