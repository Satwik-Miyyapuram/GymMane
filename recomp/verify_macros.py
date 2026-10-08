#!/usr/bin/env python3
"""Verify daily macros + 2-week budget for the final recomp protocol.
Food values per 100g (USDA FDC / NEVO-aligned, raw weights). Milk per 100ml."""

FOODS = {
 # name: (kcal, protein, carbs, fat, fiber)
 "oats":        (372, 13.5, 58.7, 7.0, 10.0),
 "egg":         (143, 12.6, 0.7, 9.5, 0.0),
 "whites":      ( 52, 11.0, 0.7, 0.2, 0.0),
 "milk":        ( 34,  3.4, 5.0, 0.1, 0.0),
 "chicken":     (120, 22.5, 0.0, 2.6, 0.0),
 "pasta":       (359, 12.5, 72.0, 1.5, 3.0),
 "rice":        (356,  7.1, 78.9, 0.7, 1.3),
 "lentils":     (352, 25.0, 60.0, 1.1, 11.0),
 "broccoli":    ( 34,  2.8,  4.4, 0.4, 2.6),
 "passata":     ( 29,  1.4,  5.0, 0.2, 1.4),
 "tin_tomato":  ( 24,  1.2,  4.1, 0.2, 1.5),
 "onion":       ( 40,  1.1,  9.3, 0.1, 1.7),
 "carrot":      ( 41,  0.9,  9.6, 0.2, 2.8),
 "mushroom":    ( 22,  3.1,  3.3, 0.3, 1.0),
 "sweet_potato":( 86,  1.6, 20.0, 0.1, 3.0),
 "banana":      ( 89,  1.1, 22.8, 0.3, 2.6),
 "apple":       ( 52,  0.3, 13.8, 0.2, 2.4),
 "oil":         (884,  0.0,  0.0, 100.0, 0.0),
 "peas":        ( 77,  5.2, 13.6, 0.4, 5.1),
}

def macros(items):
    t = [0.0]*5
    for name, grams in items.items():
        f = FOODS[name]
        for i in range(5):
            t[i] += f[i]*grams/100.0
    return t  # kcal, P, C, F, fiber

B = {"oats":40, "egg":50, "milk":350, "onion":30, "tin_tomato":40, "oil":2}
L = {"chicken":120, "pasta":80, "broccoli":150, "passata":150, "onion":40, "carrot":40, "oil":4}
D = {"chicken":110, "rice":45, "lentils":25, "broccoli":180, "mushroom":60, "onion":30, "tin_tomato":50, "oil":6}
S = {"milk":400, "banana":70, "sweet_potato":100}

for label, m in [("Breakfast",B),("Lunch",L),("Dinner",D),("Snack",S)]:
    k,p,c,f,fi = macros(m)
    print(f"{label:10s}: {k:7.0f} kcal | P {p:5.1f} | C {c:5.1f} | F {f:5.1f} | Fib {fi:4.1f}")

tot = [sum(x) for x in zip(*[macros(m) for m in (B,L,D,S)])]
k,p,c,f,fi = tot
print(f"{'TOTAL':10s}: {k:7.0f} kcal | P {p:5.1f} | C {c:5.1f} | F {f:5.1f} | Fib {fi:4.1f}")
print(f"Energy check 4P/4C/9F: {p*4+c*4+f*9:.0f} kcal")
print(f"P g/kg BW (60.75): {p/60.75:.2f} | g/kg FFM (48): {p/48:.2f}")
print(f"Fat % energy: {f*9/k*100:.1f}% | P %: {p*4/k*100:.1f}% | C %: {c*4/k*100:.1f}%")
# Energy availability check
for e in (200, 280):  # gym ~200, judo ~280 kcal
    print(f"EA (intake-{e} kcal exercise)/48kg FFM = {(k-e)/48:.1f} kcal/kg FFM")

# 1900 fallback variant: add 25g rice to dinner + 100ml milk to snack
D2 = dict(D, rice=70); S2 = dict(S, milk=500)
tot2 = [sum(x) for x in zip(*[macros(m) for m in (B,L,D2,S2)])]
k2,p2,c2,f2,fi2 = tot2
print(f"\n1900 FALLBACK: {k2:.0f} kcal | P {p2:.1f} | C {c2:.1f} | F {f2:.1f} | Fib {fi2:.1f}")
