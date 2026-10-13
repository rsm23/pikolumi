"""Original storybook vectors, with separate closed paint regions and ink details."""
import math
from copy import deepcopy
PALETTE = ['70BBC3', 'F4C75D', 'EB9BAA', 'A599CD', '8DBB88', 'EE826F', 'F8DEBE']
INK = '344850'
WHITE = 'FFFDF7'
TAN = 'D8A775'
BROWN = 'A87855'
SKY = 'DDEFF4'
LEAF = '8DBB88'
GOLD = 'F4C75D'
CORAL = 'EE826F'
LILAC = 'A599CD'
TEAL = '70BBC3'
PINK = 'EB9BAA'

def color(c):
    return PALETTE[c % len(PALETTE)] if isinstance(c, int) else c

def region(kind, c, **data):
    return {'kind': kind, 'color': color(c), 'strokeWidth': 2.5, **data}

def path(d, c=0):
    return region('path', c, d=d)

def ellipse(x, y, w, h, c=0, ink=False):
    return region('ellipse', INK if ink else c, v=[x, y, w, h], fillable=not ink, outline=not ink)

def rect(x, y, w, h, c=0, r=8):
    return region('rect', c, v=[x, y, w, h, r])

def poly(points, c=0):
    return region('poly', c, v=points)

def line(d, c=INK, width=1.8):
    return {'kind': 'stroke', 'd': d, 'color': color(c), 'strokeWidth': width, 'fillable': False, 'outline': False}

def dot(x, y, r=3, c=INK):
    return {'kind': 'ellipse', 'v': [x - r, y - r, r * 2, r * 2], 'color': color(c), 'fillable': False, 'outline': False}

def eyes(x=75, y=80, gap=45):
    return [ellipse(x, y, 7, 9, ink=True), ellipse(x + gap, y, 7, 9, ink=True), dot(x + 2, y + 2, 1, WHITE), dot(x + gap + 2, y + 2, 1, WHITE)]

def smile(x, y, w=12):
    return line(f'M{x} {y} Q{x + w / 2} {y + 6} {x + w} {y}')

def leaf(x, y, w=26, h=15, c=LEAF):
    return path(f'M{x} {y + h} Q{x - 3} {y} {x + w} {y} Q{x + w + 1} {y + h + 4} {x} {y + h} Z', c)

def star(x, y, r, c=GOLD):
    points = [(x + math.sin(i * math.pi / 5) * (r if i % 2 == 0 else r * 0.47), y - math.cos(i * math.pi / 5) * (r if i % 2 == 0 else r * 0.47)) for i in range(10)]
    return poly([[round(a, 2), round(b, 2)] for a, b in points], c)

def motif(name):
    if name == 'cat':
        s = [path('M132 150 C185 164 192 117 170 111 C158 107 154 117 162 123 C177 132 164 145 141 133 Z', TAN), path('M72 98 C52 121 51 151 63 173 Q99 191 132 174 C148 149 140 119 125 99 Z', TAN), path('M53 79 L49 26 Q50 18 60 25 L84 47 Q105 39 123 46 L146 24 Q155 19 155 30 L152 80 C156 111 138 132 103 133 C69 133 47 111 53 79 Z', TAN), path('M59 62 L58 35 L77 54 Z', PINK), path('M130 54 L146 35 L145 63 Z', PINK), path('M78 118 Q99 104 124 118 Q135 142 127 167 Q103 180 77 167 Z', WHITE), path('M69 162 Q58 159 57 172 Q75 185 91 175 L91 164 Z', TAN), path('M115 164 L115 176 Q138 182 147 172 Q144 158 131 162 Z', TAN), path('M93 92 Q102 87 111 92 L103 100 Z', PINK), line('M103 100 L103 105 M103 105 Q94 112 89 105 M103 105 Q112 112 117 105'), line('M78 95 L59 92 M78 101 L57 104 M127 95 L146 92 M127 101 L149 104')] + eyes(79, 77, 40)
    elif name == 'dog':
        s = [path('M150 125 Q183 110 183 130 Q178 148 149 145 Z', TAN), path('M67 103 Q39 106 35 140 L38 174 L63 174 L66 144 L125 146 L128 175 L153 175 L156 135 Q152 108 131 105 Z', TAN), path('M109 113 Q94 130 93 145 L120 145 Q133 129 130 116 Z', WHITE), path('M58 44 C79 30 114 32 130 57 L126 102 Q106 127 71 108 L57 80 Z', TAN), path('M57 44 Q31 35 28 67 Q27 100 50 101 Q64 89 64 64 Z', BROWN), path('M119 44 Q145 39 151 68 Q158 103 135 104 Q118 93 119 44 Z', BROWN), path('M79 89 Q94 76 110 89 Q120 115 95 117 Q72 114 79 89 Z', WHITE), ellipse(87, 87, 17, 12, ink=True), line('M96 99 Q91 108 87 103 M96 99 Q102 108 107 103'), path('M93 107 L103 107 Q104 124 97 124 Q91 120 93 107 Z', PINK), line('M42 167 L57 167 M132 167 L148 167')] + eyes(73, 66, 32)
    elif name == 'rabbit':
        s = [ellipse(134, 131, 34, 34, WHITE), path('M76 80 C60 65 53 27 65 13 C82 1 99 43 92 77 Z', WHITE), path('M114 76 C113 38 140 4 150 19 C160 43 139 76 126 86 Z', WHITE), path('M74 62 C65 41 66 24 70 24 C80 29 85 51 82 64 Z', PINK), path('M124 63 C125 46 141 22 145 27 C147 39 135 61 130 68 Z', PINK), path('M65 107 C43 132 45 163 65 174 Q102 187 135 174 C153 151 139 126 126 106 Z', WHITE), path('M54 86 Q57 59 99 58 Q144 59 150 91 C157 122 133 142 102 140 C69 141 48 121 54 86 Z', WHITE), ellipse(78, 124, 47, 48, 'F4E9DC'), ellipse(55, 163, 40, 19, WHITE), ellipse(111, 163, 40, 19, WHITE), path('M94 104 Q103 99 112 104 L104 113 Z', PINK), line('M104 112 L104 117 M104 117 Q95 124 90 118 M104 117 Q113 124 118 117')] + eyes(78, 88, 41)
    elif name == 'fox':
        s = [path('M123 135 C154 104 181 121 186 143 Q188 170 161 179 L120 170 Z', CORAL), path('M161 178 Q178 160 174 143 L186 143 Q195 173 161 179 Z', WHITE), path('M73 98 Q55 133 66 167 L87 175 L99 144 L114 175 L140 167 Q144 129 126 100 Z', CORAL), path('M58 79 L46 20 L91 51 Q105 43 119 51 L162 23 L146 85 Q138 129 104 137 Q67 126 58 79 Z', CORAL), path('M58 80 Q81 79 104 117 Q123 82 147 82 Q144 123 104 137 Q65 125 58 80 Z', WHITE), poly([[57, 38], [77, 58], [63, 67]], PINK), poly([[145, 40], [129, 58], [144, 65]], PINK), path('M91 109 Q103 102 116 109 Q115 121 104 122 Q92 119 91 109 Z', INK), ellipse(67, 164, 24, 15, BROWN), ellipse(113, 164, 26, 15, BROWN)] + eyes(76, 78, 46)
    elif name == 'bear':
        s = [ellipse(48, 25, 38, 38, TAN), ellipse(116, 25, 38, 38, TAN), ellipse(57, 33, 20, 20, 'F4D7B7'), ellipse(125, 33, 20, 20, 'F4D7B7'), path('M68 98 Q47 128 52 163 Q103 190 153 164 Q156 129 133 101 Z', TAN), ellipse(46, 41, 109, 94, TAN), ellipse(72, 88, 62, 38, 'F4D7B7'), ellipse(77, 126, 53, 44, 'F4D7B7'), path('M61 122 Q35 117 38 145 Q53 161 73 146 Z', TAN), path('M139 120 Q161 118 165 139 Q165 157 139 150 Z', TAN), ellipse(53, 160, 38, 25, TAN), ellipse(116, 160, 38, 25, TAN), ellipse(63, 164, 18, 14, 'F4D7B7'), ellipse(127, 165, 18, 14, 'F4D7B7'), ellipse(94, 94, 17, 12, ink=True), line('M103 106 L103 111 M103 111 Q92 120 88 111 M103 111 Q113 120 117 111')] + eyes(77, 72, 43)
    elif name == 'lion':
        s = [line('M140 144 Q179 139 173 110', BROWN, 5), leaf(164, 101, 22, 17, BROWN), path('M66 112 Q47 138 60 174 L84 177 L91 150 L120 151 L126 178 L151 173 Q160 140 138 115 Z', TAN), path('M48 81 Q26 63 46 47 Q41 20 68 26 Q85 7 101 23 Q122 7 139 28 Q167 25 162 51 Q185 67 164 87 Q179 113 153 122 Q148 149 124 138 Q103 158 85 138 Q57 145 53 121 Q28 111 48 81 Z', GOLD), ellipse(56, 40, 94, 93, TAN), ellipse(69, 82, 69, 37, WHITE), ellipse(94, 88, 17, 12, ink=True), line('M103 100 L103 108 M103 108 Q93 117 86 107 M103 108 Q114 117 120 107'), ellipse(59, 165, 29, 15, TAN), ellipse(124, 165, 29, 15, TAN)] + eyes(78, 69, 41)
    elif name == 'elephant':
        s = [line('M156 104 Q182 104 176 124', BROWN, 2.5), path('M69 65 C94 47 156 57 167 94 L163 169 Q154 181 141 170 L140 143 L108 143 L108 171 Q94 182 83 170 L76 120 Z', '9CAFC5'), path('M63 53 Q29 52 22 88 C10 131 40 151 75 137 Q95 124 87 91 Z', 'B9C9D7'), path('M51 71 Q27 66 25 97 Q23 129 49 133 Q77 130 74 102 Z', 'DCE5EC'), path('M83 52 C111 43 128 63 127 88 L125 140 Q128 161 145 143 L155 151 Q138 185 116 170 Q104 161 106 136 L104 108 Q73 105 73 79 Z', '9CAFC5'), path('M95 104 Q106 111 99 124 Q91 124 88 111 Z', WHITE), dot(104, 77, 4), line('M114 135 L123 135 M114 145 L126 145 M89 164 L104 164 M146 164 L159 164')]
    elif name == 'giraffe':
        s = [line('M150 107 Q175 108 176 129', BROWN, 2.5), dot(176, 129, 4, BROWN), path('M76 48 L77 99 Q95 93 145 101 Q163 109 162 138 L156 181 L144 181 L140 146 L111 147 L108 181 L95 181 L91 145 L69 143 L64 182 L51 182 L58 131 L59 64 Z', GOLD), path('M56 52 Q28 48 33 33 L55 37 Q67 13 96 28 Q110 21 122 37 Q125 49 108 62 Q78 74 56 52 Z', GOLD), path('M83 27 L80 11 L86 9 L92 29 Z', TAN), path('M101 29 L102 12 L109 12 L108 33 Z', TAN), dot(83, 10, 5, BROWN), dot(106, 12, 5, BROWN), ellipse(33, 36, 29, 18, 'F8DEBE'), ellipse(59, 76, 15, 19, TAN), ellipse(64, 107, 16, 18, TAN), ellipse(95, 108, 19, 15, TAN), ellipse(121, 111, 17, 19, TAN), ellipse(140, 129, 14, 13, TAN), dot(87, 40, 3), dot(45, 45, 2), line('M34 48 Q46 55 54 50 M54 175 L65 175 M95 175 L108 175 M145 175 L157 175')]
    elif name == 'turtle':
        s = [ellipse(44, 134, 30, 31, LEAF), ellipse(116, 134, 30, 31, LEAF), path('M35 113 L17 126 L40 132 Z', LEAF), path('M140 107 Q157 80 181 96 Q195 108 183 126 Q170 136 144 125 Z', LEAF), path('M31 120 C24 81 48 45 96 45 C143 44 167 80 158 120 Q97 147 31 120 Z', LEAF), path('M34 117 Q100 136 156 117 L154 132 Q99 153 33 132 Z', 'D7DF9D'), poly([[80, 61], [111, 61], [130, 90], [111, 119], [79, 119], [61, 89]], 'B8CF86'), line('M80 61 L68 49 M111 61 L123 51 M130 90 L159 91 M111 119 L123 135 M79 119 L67 135 M61 89 L32 89'), dot(175, 105, 3), smile(169, 117, 11)]
    elif name == 'fish':
        s = [path('M144 99 Q171 72 189 64 Q176 99 189 136 Q171 128 144 102 Z', GOLD), path('M74 73 Q98 36 123 68 L126 93 Z', CORAL), path('M86 124 Q113 152 130 131 L111 112 Z', CORAL), path('M16 103 C36 63 82 49 129 76 Q163 103 130 130 C89 151 39 142 16 103 Z', TEAL), line('M62 72 Q79 101 63 135'), path('M94 102 Q111 84 131 93 Q116 113 94 112 Z', GOLD), dot(42, 98, 4), smile(25, 112, 12), line('M153 98 L180 86 M154 104 L179 118', BROWN, 1.3)]
    elif name == 'bird':
        s = [path('M64 129 L24 161 Q26 135 36 117 L63 103 Z', LILAC), line('M72 147 L72 171 L91 171 M119 145 L127 170 L145 170', BROWN, 3), path('M53 131 C36 110 41 80 61 56 Q64 27 86 40 Q99 21 111 43 C148 45 164 74 152 106 Q156 147 111 157 Q76 162 53 131 Z', TEAL), path('M131 69 L173 87 L136 101 Z', GOLD), path('M76 104 Q113 93 134 115 Q123 153 93 151 Q68 145 76 104 Z', GOLD), path('M53 96 Q91 77 107 107 Q89 135 61 123 Z', LILAC), dot(119, 70, 4), smile(115, 97, 11)]
    elif name == 'owl':
        s = [ellipse(58, 164, 27, 14, GOLD), ellipse(118, 164, 27, 14, GOLD), path('M39 54 L37 26 L72 43 Q101 30 133 43 L163 26 L160 64 Q170 142 138 166 Q103 181 65 164 Q28 136 39 54 Z', TAN), path('M39 90 Q64 96 67 154 Q40 148 36 118 Z', BROWN), path('M161 90 Q138 96 134 155 Q159 145 166 119 Z', BROWN), path('M51 82 C51 49 91 43 101 68 C114 41 154 48 153 83 Q151 120 102 140 Q53 120 51 82 Z', WHITE), ellipse(65, 65, 24, 27, 'E8DAC4'), ellipse(114, 65, 24, 27, 'E8DAC4'), poly([[94, 94], [110, 94], [102, 108]], GOLD), line('M82 145 Q89 151 95 145 M108 145 Q115 151 121 145')] + eyes(73, 71, 48)
    elif name == 'penguin':
        s = [ellipse(54, 166, 41, 16, GOLD), ellipse(111, 166, 41, 16, GOLD), path('M60 99 Q29 108 27 140 Q49 143 67 119 Z', '607D91'), path('M140 99 Q173 109 176 137 Q157 147 135 119 Z', '607D91'), path('M49 135 C41 111 50 97 58 83 Q56 32 103 28 Q148 31 147 84 C158 111 163 133 146 158 Q102 187 61 158 Z', '607D91'), path('M65 84 C59 52 88 49 104 67 C121 49 145 54 138 86 C134 104 141 121 140 142 Q111 169 78 150 Q65 135 69 111 Z', WHITE), path('M93 88 L116 88 L104 102 Z', GOLD), ellipse(75, 104, 13, 8, PINK), ellipse(119, 104, 13, 8, PINK)] + eyes(78, 75, 43)
    elif name == 'butterfly':
        s = [path('M92 84 C76 44 41 13 20 38 C-1 66 34 105 88 107 Z', PINK), path('M107 84 C128 43 160 15 182 39 C202 70 167 105 111 109 Z', LILAC), path('M88 103 C35 104 19 139 39 162 C59 180 82 151 94 120 Z', LILAC), path('M111 105 C165 104 183 140 164 165 C142 181 120 151 106 123 Z', PINK), path('M51 55 Q30 62 47 85 Q70 94 78 86 Q69 63 51 55 Z', 'F9D8DE'), path('M149 54 Q173 67 153 87 Q134 96 123 88 Q132 64 149 54 Z', 'D9CFED'), ellipse(49, 126, 21, 22, GOLD), ellipse(134, 127, 21, 22, GOLD), path('M94 67 Q102 57 108 70 L112 128 Q103 150 94 130 Z', TAN), ellipse(89, 54, 25, 25, TAN), line('M94 56 Q85 27 76 35 M106 56 Q118 26 126 35')] + eyes(94, 60, 9)
    elif name == 'bee':
        s = [line('M55 121 L44 143 L28 144 M83 129 L76 154 L59 158 M116 129 L126 154 L142 156 M57 88 L41 75 L28 79 M79 73 L73 54 L58 50 M116 75 L132 61 L147 65', BROWN, 2.3), ellipse(46, 28, 54, 60, WHITE), ellipse(103, 27, 53, 60, WHITE), path('M29 109 C28 65 69 64 101 69 Q148 62 170 92 C188 138 136 161 92 153 C58 155 32 136 29 109 Z', GOLD), path('M69 71 Q90 108  70 150 L86 153 Q107 107 86 69 Z', BROWN), path('M111 70 Q132 108 115 153 L134 151 Q150 110 132 72 Z', BROWN), path('M153 94 Q169 86 181 99 Q191 125 166 135 Q147 126 153 94 Z', GOLD), line('M167 96 Q160  70 157 81 M178 95 Q186 78 190  80'), dot(174, 107, 3), smile(170, 119, 9)]
    elif name == 'snail':
        s = [path('M18 146 Q43 131 115 139 L149 106 Q157 92 175 102 Q189 113 175 145 L169 165 L35 171 Q15 169 18 146 Z', LEAF), line('M160 107 L153 82 M174 107 L180 84', INK, 2), dot(153, 81, 4), dot(180, 82, 4), path('M48 145 C17 123 24 69 59 51 C107 26 152 55 147 99 Q143 139 109 150 Z', TAN), line('M111 131 C72 147 43 119 52 91 C62 63 111 64 122 91 C132 116 101 127 89 111 C77 96 93 86 102 96', BROWN, 2.8), smile(154, 133, 15)]
    elif name == 'octopus':
        s = []
        for i in range(8):
            x = 24 + i * 19
            s.append(path(f'M{x} 108 C{x - 8} 132 {x - 12} 158 {x - 6} 172 Q{x + 6} 188 {x + 18} 170 L{x + 13} 161 Q{x + 6} 170 {x + 4} 156 L{x + 19} 111 Z', LILAC))
        s += [path('M38 103 C31 62 53 22 100 20 C147 22 170 65 162 105 Q160 131 102 131 Q43 129 38 103 Z', LILAC), ellipse(66, 93, 13, 8, PINK), ellipse(122, 93, 13, 8, PINK), smile(89, 106, 23)] + eyes(72, 75, 44)
    elif name == 'whale':
        s = [path('M140 112 Q172 81 191 82 Q192 101 179 111 Q195 122 190 141 Q169 143 149 129 Z', TEAL), path('M17 124 C3 77 36  50 81  60 C114  60 136 91 151 117 Q155 151 121 162 Q51 182 17 124 Z', TEAL), path('M18 126 Q72 160 147 130 Q134 166  70 165 Q30 160 18 126 Z', 'DDEFF4'), path('M89 128 Q98 113 117 119 Q115 150 95 153 Z', TEAL), path('M64 54 Q47 29 51 18 Q69 23  70 49 Z', SKY), path('M77 52 Q79 19 99 18 Q103 31 86 55 Z', SKY), dot(34, 108, 4), smile(22, 129, 20)]
    elif name == 'frog':
        s = [path('M55 137 Q21 132 17 159 Q16 177 61 174 L76 163 Z', LEAF), path('M139 137 Q177 128 186 157 Q190 175 147 175 L128 161 Z', LEAF), path('M63 114 Q39 143 69 172 Q102 181 134 170 Q161 144 139 116 Z', LEAF), ellipse(38, 53, 58, 61, LEAF), ellipse(105, 53, 58, 61, LEAF), path('M44  90 Q34 144 100 150 Q167 147 158 90 Q128 76 102 92 Q76 73 44 90 Z', LEAF), ellipse(58, 65, 25, 30, WHITE), ellipse(120, 65, 25, 30, WHITE), dot(70, 79, 5), dot(131, 79, 5), path('M71 125 Q102 140 134 124 Q130 139 101 142 Q76 137 71 125 Z', 'D7DF9D'), line('M29 163 L40 156 M41 169 L47 158 M167 160 L176 166 M157 160 L163 170')]
    elif name == 'hedgehog':
        s = [ellipse(61, 157, 27, 19, TAN), ellipse(123, 157, 27, 19, TAN), path('M37 128 L24 111 L37 98 L29 83 L46 78 L45 61 L64 59 L72 41 L91 46 L107 29 L124 43 L145 35 L153 57 L176 63 L169 84 L183 103 L169 119 L176 141 Q127 173 68 157 Z', BROWN), path('M39 117 Q53 104  70 120 Q97 151 159 145 Q164 170 99 169 Q61 166 31 139 L13 134 L15 124 Z', TAN), line('M52 86 L72 75 L84 91 M91 59 L111 58 L120 76 M128 91 L149 79 L158 99 M78 113 L98 99 L114 112', TAN, 2), dot(16, 129, 5), dot(45, 125, 3), smile(30, 142, 14)]
    elif name == 'apple':
        s = [path('M100 49 C66 25 21  40 23 92 C22 130 50 180 83 178 Q101 168 120 178 C153 181 177 129 178 90 C180 39 140 28 100 49 Z', CORAL), path('M97 49 Q93 25 101 16 L112 17 Q105 35 108 49 Z', BROWN), leaf(109, 20, 40, 22, LEAF), line('M44 74 Q35 94 41 113', 'F8C2B5', 3)]
    elif name == 'pear':
        s = [path('M92 39 Q116 29 128 58 Q131 82 151 105 C184 148 160 181 103 185 C 40 184 16 154  50 111 Q 70 85 73 62 Q77 44 92 39 Z', 'B8CF86'), path('M93 41 L98 16 L108 18 L105  40 Z', BROWN), leaf(106, 22, 36, 20, LEAF), line('M78 104 Q62 133 78 158', 'E5ECC2', 3)]
    elif name == 'banana':
        s = [path('M41  30 Q49 137 148 135 Q165 136 181 118 L189 131 C163 185 98 197 51 151 C23 124 14 71 28  30 Z', GOLD), path('M42  40 Q48 145 159 151 Q170 143 181 130 C137 172 57 159  30 78 Z', 'F9DEA0'), path('M27  30 L31 15 L43 18 L42  30 Z', BROWN), path('M180 118 L190 116 L193 126 L188 133 Z', BROWN)]
    elif name == 'strawberry':
        s = [path('M27  70 C31 43 73 43 100  50 C129 41 170 43 176 73 Q172 135 102 183 Q 30 136 27  70 Z', CORAL), path('M53 56 L 70 34 L88 45 L102 24 L115 44 L139 32 L147 55 L128  70 L109 59 L97 77 L83  60 L63  70 Z', LEAF), path('M99  30 L103 12 L111 14 L107 35 Z', LEAF)]
        for x, y in [(55, 88), (88, 92), (131, 89), (67, 119), (113, 124), (94, 151)]:
            s.append(ellipse(x, y, 5, 9, 'F8DEBE'))
    elif name == 'carrot':
        s = [path('M 70 61 C29 39 36 16 57 24 Q75 33 89  60 Q83 18 102 9 Q125 12 109  60 Q127 24 151 24 Q165 51 124 68 Z', LEAF), path('M55 67 Q99 50 147 68 Q140 127 91 188 Q61 153 55 67 Z', CORAL), line('M60 89 L84 93 M122 111 L140 107 M 70 130 L91 135 M108 153 L122 147', BROWN, 1.8)]
    elif name == 'orange':
        s = [ellipse(25, 40, 151, 142, 'F0AD5D'), path('M93 41 Q91 25 102 19 L109 23 L104 43 Z', BROWN), leaf(108, 21, 38, 22, LEAF), line('M47 79 Q 30 104  40 127', 'F9D995', 3)]
        for x, y in [(126, 126), (143, 104), (120, 148), (141, 143)]:
            s.append(dot(x, y, 1.5, 'E69645'))
    elif name == 'watermelon':
        s = [path('M14 52 L185 52 Q176 179 101 185 Q27 175 14 52 Z', LEAF), path('M26 59 L173 59 Q164 164 101 173 Q40 163 26 59 Z', WHITE), path('M37  60 L162  60 Q151 150 101 161 Q51 152 37  60 Z', PINK)]
        for x, y in [(57, 80), (94, 89), (132, 81), (78, 120), (115, 127)]:
            s.append(ellipse(x, y, 5, 10, ink=True))
    elif name == 'bread':
        s = [path('M31 157 L24 93 C5  60 29  30 62 36 Q91 13 120 34 C157 28 189 51 172 91 L166 156 Q103 174 31 157 Z', TAN), path('M45 145 L42 91 Q 30 65 64  60 Q92 43 119 58 Q153 50 156 76 L151 145 Q100 156 45 145 Z', 'F8DEBE'), line('M57 74 Q68 64 80 68 M91 62 Q105 53 119 64 M126 73 Q138 66 147 75', BROWN, 2.8)]
    elif name == 'cake':
        s = [rect(29, 84, 142, 85, 'F4C2C9', 10), path('M28 91 L28 77 Q99 62 172 77 L172 96 Q157 117 145 96 Q127 121 109 99 Q90 122 74 98 Q53 121  40 97 Z', WHITE), rect(33, 128, 133, 12, 'E8A788', 4), ellipse(17, 159, 165, 22, TEAL), rect(94, 33, 12, 40, TEAL, 3), path('M100  30 Q85 15 101 5 Q116 20 100  30 Z', GOLD)]
    elif name == 'cup':
        s = [path('M139  60 C195 47 198 129 142 134 L139 116 Q174 111 172 87 Q170 68 141 79 Z', TEAL), path('M28 54 L147 54 L139 147 Q 90 179 39 148 Z', TEAL), ellipse(28, 40, 119, 29, WHITE), ellipse(39, 48, 97, 13, 'B9DAE0'), ellipse(17, 161, 151, 16, TEAL), line('M 50 98 Q 50 130  60 136', 'B9DAE0', 3)]
    elif name == 'car':
        s = [path('M19 129 L22 104 Q26 90 49 87 L 70 49 Q75  40 90  40 L129  40 Q143 41 158 85 Q181 88 186 108 L185 133 Z', CORAL), path('M57 88 L77 52 L96 52 L96 88 Z', SKY), path('M108 52 L128 52 Q139 54 148 88 L108 88 Z', SKY), ellipse(36, 115, 40, 40, '657789'), ellipse(124, 115, 40, 40, '657789'), ellipse(47, 126, 18, 18, WHITE), ellipse(135, 126, 18, 18, WHITE), rect(169, 103, 14, 13, GOLD, 4), rect(22, 101, 12, 13, GOLD, 3), line('M101 92 L101 116 M112 101 L124 101', INK, 1.6)]
    elif name == 'bus':
        s = [path('M22 49 Q22 34  40 34 L165 34 Q181 36 183  50 L183 140 L22 140 Z', GOLD), rect(30, 54, 30, 41, SKY, 5), rect(68, 54, 30, 41, SKY, 5), rect(106, 54, 30, 41, SKY, 5), rect(146, 54, 26, 73, SKY, 4), ellipse(35, 120, 40, 40, '657789'), ellipse(132, 120, 40, 40, '657789'), ellipse(46, 131, 18, 18, WHITE), ellipse(143, 131, 18, 18, WHITE), line('M24 105 L138 105 M159 59 L159 122'), rect(174, 113, 9, 10, CORAL, 3)]
    elif name == 'train':
        s = [rect(81, 58, 49, 63, TEAL, 9), rect(126, 32, 52, 91, CORAL, 5), rect(135, 43, 31, 36, SKY, 4), rect(31, 78, 51, 40, TEAL, 6), rect(43, 38, 20, 40, GOLD, 3), rect(35, 31, 35, 12, CORAL, 4), rect(20, 119, 163, 17, GOLD, 4), poly([[20, 111], [5, 138], [27, 136]], CORAL), ellipse(36, 124, 35, 35, '657789'), ellipse(80, 123, 36, 36, '657789'), ellipse(137, 118, 42, 42, '657789'), ellipse(46, 134, 15, 15, WHITE), ellipse(90, 133, 16, 16, WHITE), ellipse(149, 130, 18, 18, WHITE), line('M57 144 L157 144', CORAL, 4), path('M42 20 Q22 17 29 7 Q37 0 48 9 Q66 3 71 17 Z', SKY)]
    elif name == 'boat':
        s = [path('M13 123 L186 123 L162 163 Q100 186  40 162 Z', CORAL), path('M16 124 L181 124 L174 139 L26 139 Z', WHITE), rect(99, 20, 6, 105, TAN, 2), path('M92 27 L92 113 L22 113 Q33 73 92 27 Z', GOLD), path('M112 43 L175 113 L112 113 Z', TEAL), line('M13 180 Q34 171 55 180 T97 180 T139 180 T181 180', TEAL, 2.5)]
    elif name == 'rocket':
        s = [path('M 60 102 Q 30 125  20 157 L 60 148 Z', CORAL), path('M140 102 Q171 126 181 157 L140 148 Z', CORAL), path('M 70 143 Q79 177 101 194 Q127 174 132 143 Z', GOLD), path('M88 146 Q89 166 101 179 Q112 166 113 146 Z', CORAL), path('M64 147 L 60  90 C61  50 82 21 100 8 C124 24 141  50 141  90 L136 147 Z', WHITE), path('M76 38 Q89 16 100 8 Q115 20 127 38 Z', CORAL), ellipse(79, 57, 43, 43, TEAL), ellipse(88, 66, 25, 25, SKY), rect(65, 133, 70, 13, TEAL, 2)]
    elif name == 'airplane':
        s = [path('M 90 29 Q100 8 111 29 L120 78 L189 119 L188 134 L116 112 L112 158 L140 176 L136 185 L100 176 L64 185 L 60 176 L88 158 L85 113 L14 134 L11 119 L80 78 Z', WHITE), path('M93 38 Q101  20 108 38 L110  60 L91  60 Z', TEAL), path('M119 83 L175 119 L162 121 L117 102 Z', CORAL), path('M81 83 L24 119 L37 121 L85 102 Z', CORAL), line('M100  80 L100 164', TEAL, 2.5)]
    elif name == 'bicycle':
        s = [ellipse(9, 104, 60, 60, '657789'), ellipse(131, 104, 60, 60, '657789'), ellipse(15, 110, 48, 48, WHITE), ellipse(137, 110, 48, 48, WHITE), line('M39 134 L 70 80 L112 134 L39 134 M 70 80 L132 80 L112 134 M132 80 L161 134 M 70 80 L65 65 M129 80 L125 57 L147 57', CORAL, 5), rect(50, 59, 32, 8, BROWN, 3), ellipse(105, 127, 14, 14, GOLD), line('M112 134 L122 144 L132 144', BROWN, 2.5), dot(39, 134, 3), dot(161, 134, 3)]
    elif name == 'tractor':
        s = [rect(28, 89, 83, 43, CORAL, 8), rect(105, 54, 49, 75, CORAL, 7), rect(113, 63, 33, 36, SKY, 3), rect(95, 42, 67, 13, GOLD, 4), rect(36, 56, 9, 35, '657789', 2), ellipse(20, 118, 39, 39, '657789'), ellipse(115, 108, 60, 60, '657789'), ellipse(30, 128, 19, 19, GOLD), ellipse(132, 125, 26, 26, GOLD), line('M59 103 L91 103 M59 111 L91 111'), rect(20, 100, 9, 11, GOLD, 2)]
    elif name == 'tree':
        s = [path('M84 111 L 80 184 L126 184 L115 112 L141  80 L132  70 L108 97 L98 71 L88  70 L92 104 L68 88 L61 96 Z', TAN), path('M28 108 C5 84 28 57 48 59 Q38 31  70 25 Q94 1 115 25 Q153 15 159 53 Q195 60 183 91 Q189 116 155 121 L 50 124 Q32 124 28 108 Z', LEAF), line('M40 89 Q53 102 64 96 M126 37 Q144 35 148 51', 'B8D2A2', 3)]
    elif name == 'flower':
        s = [path('M96 92 L106 92 L105 185 L96 185 Z', LEAF), leaf(50, 123, 49, 29, LEAF), leaf(107, 144, 49, 26, LEAF)]
        for i in range(8):
            a = i * math.pi / 4
            x = 100 + math.sin(a) * 35
            y = 70 + math.cos(a) * 35
            s.append(ellipse(x - 18, y - 22, 36, 44, PINK if i % 2 == 0 else 'F5BFBD'))
        s += [ellipse(79, 49, 42, 42, GOLD)]
    elif name == 'sun':
        s = []
        for i in range(12):
            a = i * math.pi / 6
            x, y = (100 + math.sin(a) * 72, 100 + math.cos(a) * 72)
            x2, y2 = (100 + math.sin(a) * 89, 100 + math.cos(a) * 89)
            s.append(line(f'M{x:.2f} {y:.2f} L{x2:.2f} {y2:.2f}', GOLD, 5))
        s += [ellipse(40, 40, 120, 120, GOLD)] + eyes(70, 87, 50) + [smile(89, 117, 20)]
    elif name == 'moon':
        s = [path('M147 17 C49 2 9 89 39 144 C70 199 142 198 183 147 C112 174 56 92 98 44 Q118 24 147 17 Z', GOLD), star(152, 76, 23, LILAC)]
    elif name == 'star':
        s = [star(100, 103, 86, GOLD)] + eyes(74, 94, 45) + [smile(88, 124, 23)]
    elif name == 'cloud':
        s = [path('M40 148 C8 151 2 123 15 106 Q21 92 39 94 C31  60 61 43 85 54 Q109 28 138 53 Q167 49 171  80 Q198  80 193 112 Q202 145 173 148 Z', WHITE)]
    elif name == 'rainbow':
        s = []
        for i, c in enumerate([CORAL, GOLD, LEAF, TEAL, LILAC]):
            x = 14 + i * 15
            right = 186 - i * 15
            inner = x + 14
            ri = right - 14
            top = 18 + i * 15
            s.append(path(f'M{x} 174 C{x} {top} {right} {top} {right} 174 L{ri} 174 C{ri} {top + 20} {inner} {top + 20} {inner} 174 Z', c))
    elif name == 'leaf':
        s = [path('M33 168 C1  70 67 17 176 20 C171 137 109 185 33 168 Z', LEAF), line('M23 181 L151  40 M53 151 L52 111 M76 128 L75 86 M98 104 L100 65 M 70 134 L109 133 M94 110 L134 108 M119  80 L154 81', '628A60', 2)]
    elif name == 'mountain':
        s = [path('M5 180 L 70 25 Q75 18  80 29 L149 180 Z', LILAC), path('M88 180 L139 53 Q146  40 154 57 L197 180 Z', TEAL), path('M51  70 L 70 25 Q75 18  80 29 L101 76 L84 66 L75 81 L 60 66 Z', WHITE), poly([[125, 84], [145, 48], [165, 87], [150, 77], [140, 91]], WHITE)]
    elif name == 'mushroom':
        s = [path('M79 93 L124 93 L135 175 Q104 191  60 174 Z', WHITE), path('M13 107 C24 43  50 16 100 16 C151 16 180 46 190 107 Q105 129 13 107 Z', CORAL), ellipse(44, 60, 26, 24, WHITE), ellipse(91, 37, 29, 27, WHITE), ellipse(134, 74, 25, 20, WHITE), line('M92 137 L89 163', TAN, 1.8)]
    elif name == 'house':
        s = [rect(35, 84, 130, 100, 'F8DEBE', 4), rect(70, 122, 40, 62, TEAL, 5), rect(124, 103, 28, 34, SKY, 3), rect(47, 103, 28, 34, SKY, 3), rect(129, 31, 17, 40, CORAL, 2), path('M15 92 L94  20 Q100 14 108 23 L187 92 L169 103 L100  40 L32 103 Z', CORAL), line('M138 104 L138 136 M125 120 L151 120 M61 104 L61 136 M48 120 L74 120'), dot(101, 153, 2, GOLD)]
    elif name == 'book':
        s = [path('M100 43 Q56 19 15 38 L15 161 Q64 146 100 171 Z', TEAL), path('M100 43 Q145 19 186 38 L186 161 Q139 146 100 171 Z', CORAL), path('M94 47 Q58 30 25 43 L25 150 Q64 144 94 159 Z', WHITE), path('M107 47 Q146 30 176 43 L176 150 Q139 144 107 159 Z', WHITE), line('M39  70 Q 60 65 81 75 M39 91 Q 60 85 81 95 M39 111 Q 60 106 81 115 M121  70 Q143 65 164 74 M121 91 Q142 86 164 96 M121 111 Q143 106 164 115', 'B9CBCB', 1.4), line('M100 44 L100 168', TAN, 2)]
    elif name == 'pencil':
        s = [path('M39 144 L141  30 L167 53 L64 167 Z', GOLD), path('M48 151 L150 38 L158 46 L56 159 Z', 'F9DEA0'), path('M141  30 L155 14 Q161 10 166 15 L182  30 Q187 35 181 42 L167 53 Z', PINK), path('M39 144 L64 167 L19 188 Z', 'F8DEBE'), poly([[19, 188], [27, 167], [39, 180]], INK), line('M143  30 L167 53', 'B9CBCB', 3)]
    elif name == 'ball':
        s = [ellipse(17, 17, 166, 166, TEAL), path('M 40 44 Q81  70 105 115 Q119 148 121 181 Q159 164 176 134 Q149 94 133 53 Q 90 13  40 44 Z', GOLD), path('M22 129 Q45 119 74 106 Q127 75 162  40 Q177 62 181 85 Q137 119 91 136 Q57 150  30 154 Z', CORAL)]
    elif name == 'kite':
        s = [poly([[101, 15], [172, 84], [101, 151], [29, 84]], TEAL), poly([[101, 15], [101, 84], [29, 84]], GOLD), poly([[101, 84], [172, 84], [101, 151]], PINK), line('M101 15 L101 151 M29 84 L172 84 M101 151 Q134 163 110 178 Q91 191 121 194', BROWN, 1.8), path('M113 170 L131 164 L126 180 Z', CORAL), path('M113 170 L97 164 L103 182 Z', CORAL)]
    elif name == 'umbrella':
        s = [line('M101 88 L101 163 Q102 186 83 184 Q66 182 72 168', BROWN, 6), path('M10 100 Q18 22 100 18 Q180 22 190 100 Q166 77 144 100 Q120 77 100 100 Q79 77 57 100 Q33 77 10 100 Z', PINK), path('M57 100 Q58 41 100 18 Q137 41 144 100 Q121 77 100 100 Q80 77 57 100 Z', 'F4BFCD'), line('M100 18 L100 100'), dot(100, 15, 3, BROWN)]
    elif name == 'clock':
        s = [ellipse(17, 17, 166, 166, TEAL), ellipse(29, 29, 142, 142, WHITE), line('M100  40 L100 50 M100 150 L100 160 M 40 100 L50 100 M150 100 L160 100', INK, 2), line('M100 100 L100  60 M100 100 L135 119', CORAL, 4), dot(100, 100, 5, GOLD)]
    elif name == 'key':
        s = [path('M 70 105 L149 184 L166 167 L149 151 L161 139 L150 128 L138 140 L94 96 Q126 66 96 32 Q63 5  30 32 Q5 64 34 93 Q 50 112 70 105 Z', GOLD), ellipse(39, 30, 46, 46, WHITE)]
    elif name == 'guitar':
        s = [path('M 80  80 C52 61 41 93 53 107 C6 134 31 181 65 186 Q108 196 131 166 Q151 132 125 115 Q143 87 120 79 Z', TAN), path('M95 103 L141  30 L156  40 L112 113 Z', BROWN), rect(140, 10, 24, 39, BROWN, 4), ellipse(70, 106, 31, 31, INK), line('M83  80 L147  30 M88 84 L152 33', WHITE, 1.1), rect(65, 151, 40, 9, BROWN, 2), dot(141, 18, 3, GOLD), dot(163, 26, 3, GOLD)]
    elif name == 'drum':
        s = [path('M25 64 L175 64 L172 157 Q101 183 28 157 Z', CORAL), ellipse(25, 45, 150, 40, GOLD), ellipse(32, 51, 136, 27, WHITE), line('M32 84 L57 152 L82 84 L107 158 L133 84 L163 153', GOLD, 3), path('M27 147 Q100 173 173 147 L172 159 Q99 185 28 159 Z', GOLD), line('M30 33 L125 71 M166 27 L95 72', BROWN, 4), dot(29, 32, 5, TAN), dot(167, 26, 5, TAN)]
    elif name == 'piano':
        s = [rect(13, 43, 174, 123, LILAC, 10), rect(22, 70, 156, 80, WHITE, 2)]
        for i in range(1, 7):
            s.append(line(f'M{22 + i * 156 / 7:.2f} 70 L{22 + i * 156 / 7:.2f} 150', '778B9B', 1.2))
        for i in [0, 1, 3, 4, 5]:
            s.append(rect(37 + i * 22, 70, 13, 47, INK, 2))
        s += [rect(151, 54, 13, 7, TEAL, 2), rect(133, 54, 13, 7, PINK, 2)]
    elif name == 'bell':
        s = [ellipse(80, 20, 40, 27, GOLD), ellipse(87, 144, 28, 30, TAN), path('M 30 144 Q51 123 50 90 C49 56  70 42 101 42 C134 42 154  60 153 93 Q154 124 176 144 Z', GOLD), path('M30 136 Q103 155 175 136 L181 150 Q103 174 24 150 Z', GOLD), line('M 70  80 Q68 100  70 111', 'F9DEA0', 4)]
    else:
        raise ValueError(name)
    for i, shape in enumerate(s):
        shape.setdefault('id', f'r{i}')
    return s
THEMES = ['garden', 'forest', 'beach', 'ocean', 'night', 'snow', 'space', 'town', 'farm', 'desert', 'rain', 'party']

def transformed(shapes, x, y, scale):
    out = deepcopy(shapes)
    for shape in out:
        previous = shape.get('transform', [0, 0, 1])
        shape['transform'] = [round(x + previous[0] * scale, 3), round(y + previous[1] * scale, 3), round(previous[2] * scale, 4)]
    return out

def scene(name, variant, puzzle=False):
    theme = THEMES[variant % 12]
    sky = {'night': 'D6DDF1', 'space': 'DAD9EC', 'ocean': 'DBEEF2', 'snow': 'E6EFF7', 'desert': 'F8E6CE', 'rain': 'E1EBF0'}.get(theme, 'E6F2F3')
    s = [{'kind': 'rect', 'v': [0, 0, 600, 600, 0], 'color': sky, 'id': 'background', 'outline': False, 'role': 'background'}, {'kind': 'path', 'd': 'M0 426 C132 395 197 448 303 421 C426 389 518 406 600 438 L600 600 L0 600 Z', 'color': 'DFEBCB' if theme not in ['ocean', 'beach', 'snow', 'space', 'night'] else {'ocean': 'B9DEE5', 'beach': 'F8E5BC', 'snow': 'FFFDF7', 'space': 'BDB9DB', 'night': 'C4D1C5'}[theme], 'outline': False, 'role': 'background'}]
    s += [line('M0 426 C132 395 197 448 303 421 C426 389 518 406 600 438', 'BCCFA4' if theme not in ['ocean', 'beach', 'snow', 'space', 'night'] else 'A8C4D1', 2),
          line('M0 463 Q114 438 221 465 M403 463 Q523 443 600 465', 'BCCFA4' if theme not in ['ocean', 'beach', 'snow', 'space', 'night'] else 'A8C4D1', 2)]
    if theme in ['night', 'space']:
        s += transformed(motif('moon'), 423, 12, 0.68)
        for x, y, r in [(51, 65, 14), (183, 35, 10), (295, 110, 14), (369, 48, 9), (555, 240, 11)]:
            s.append(star(x, y, r, GOLD))
    elif theme == 'ocean':
        s += transformed(motif('fish'), 14, 29, 0.65) + transformed(motif('fish'), 415, 43, 0.6)
        for x, y, r in [(51, 201, 9), (526, 180, 13), (559, 144, 6), (86, 255, 5)]:
            s.append(ellipse(x, y, r * 2, r * 2, 'EAF7F7'))
    elif theme == 'rain':
        s += transformed(motif('cloud'), 24, 18, 0.9) + transformed(motif('cloud'), 370, 31, 0.8)
        for x, y in [(89, 162), (183, 122), (319, 93), (422, 173), (535, 209)]:
            s.append(path(f'M{x} {y} Q{x - 15} {y + 24} {x} {y + 28} Q{x + 15} {y + 24} {x} {y} Z', TEAL))
    else:
        s += transformed(motif('sun'), 438, 12, 0.65) + transformed(motif('cloud'), 20, 23, 0.86) + transformed(motif('cloud'), 237, 9, 0.6)
    if theme == 'garden':
        s += transformed(motif('flower'), 10, 334, 0.86) + transformed(motif('butterfly'), 426, 242, 0.68)
    elif theme == 'forest':
        s += transformed(motif('tree'), -3, 177, 1.02) + transformed(motif('tree'), 428, 213, 0.85) + transformed(motif('mushroom'), 451, 448, 0.5)
    elif theme == 'beach':
        s += transformed(motif('umbrella'), -3, 281, 0.94) + transformed(motif('boat'), 427, 325, 0.74) + transformed(motif('star'), 479, 483, 0.3)
    elif theme == 'ocean':
        s += transformed(motif('leaf'), -3, 384, 0.82) + transformed(motif('leaf'), 452, 351, 0.76) + transformed(motif('fish'), 25, 467, 0.5)
    elif theme == 'night':
        s += transformed(motif('tree'), -4, 270, 0.92) + transformed(motif('owl'), 458, 338, 0.6)
    elif theme == 'snow':
        s += transformed(motif('tree'), -10, 290, 0.97) + transformed(motif('house'), 424, 350, 0.84)
        for x, y in [(32, 219), (550, 235), (153, 311), (445, 293)]:
            s.append(star(x, y, 12, WHITE))
    elif theme == 'space':
        s += transformed(motif('rocket'), -1, 275, 0.96) + transformed(motif('star'), 454, 369, 0.62)
        s.append(ellipse(448, 494, 104, 52, 'D6CBE9'))
    elif theme == 'town':
        s += transformed(motif('house'), -6, 253, 1.0) + transformed(motif('car'), 419, 414, 0.87)
    elif theme == 'farm':
        s += transformed(motif('tractor'), -8, 359, 0.95) + transformed(motif('carrot'), 469, 350, 0.63)
        s += [line('M3 525 Q111 504 188 531 M401 535 Q489 501 594 522', TAN, 2)]
    elif theme == 'desert':
        s += transformed(motif('mountain'), -10, 250, 1.0) + transformed(motif('mountain'), 421, 215, 0.97) + transformed(motif('leaf'), 447, 424, 0.63)
    elif theme == 'rain':
        s += transformed(motif('umbrella'), 438, 323, 0.78) + transformed(motif('flower'), 13, 413, 0.64)
        s += [ellipse(229, 526, 138, 27, 'C2DFE4')]
    elif theme == 'party':
        s += [line('M0 18 Q300 86 600 18', BROWN, 2)]
        for i in range(7):
            x = 27 + i * 80
            y = 29 + 22 * math.sin((i + 0.3) * math.pi / 7)
            s.append(path(f'M{x} {y:.2f} L{x + 42} {y + 4:.2f} L{x + 22} {y + 48:.2f} Z', [CORAL, GOLD, TEAL, LILAC][i % 4]))
        s += transformed(motif('cake'), -4, 389, 0.8) + transformed(motif('ball'), 461, 397, 0.66)
    if puzzle:
        accents = []
        for row in range(5):
            for col in range(5):
                x = 22 + col * 120 + row % 2 * 17
                y = 22 + row * 116
                if row < 2:
                    if theme in ['night', 'space']:
                        accents += [star(x + 27, y + 26, 8 + (col + row) % 5, GOLD), dot(x + 56, y + 38, 2, WHITE)]
                    elif theme == 'ocean':
                        accents += [ellipse(x + 10, y + 19, 15 + col * 2, 15 + col * 2, 'F2FAFA'), line(f'M{x + 38} {y + 45} Q{x + 53} {y + 37} {x + 68} {y + 45}', TEAL, 1.6)]
                    else:
                        accents += transformed(motif('cloud'), x, y, 0.25 + col * 0.012)
                elif theme in ['space', 'night']:
                    accents += [path(f'M{x} {y + 67} Q{x + 24} {y + 51} {x + 63} {y + 66} L{x + 57} {y + 80} L{x + 7} {y + 81} Z', 'C6BADD'), ellipse(x + 27, y + 60, 13 + col, 8, 'E4DDF1')]
                elif theme == 'ocean':
                    accents += [line(f'M{x + 15} {y + 80} Q{x - 8} {y + 30} {x + 15} {y + 12} M{x + 15} {y + 68} Q{x + 49} {y + 34} {x + 33} {y + 23}', LEAF, 5), ellipse(x + 62, y + 40, 7 + col * 2, 7 + col * 2, 'F2FAFA')]
                else:
                    accents += [leaf(x + 6, y + 58, 24 + col * 3, 15, LEAF), line(f'M{x + 43} {y + 81} L{x + 43} {y + 46}', LEAF, 2.5), ellipse(x + 32, y + 34, 22, 20, [PINK, GOLD, LILAC, CORAL, WHITE][col]), dot(x + 43, y + 44, 3, GOLD)]
        s[4:4] = accents
    s += transformed(motif(name), 141 + variant % 3 * 7, 184 + variant % 2 * 12, 1.7)
    if theme not in ['ocean', 'space']:
        for x, y in [(189, 548), (413, 552)]:
            s.append(leaf(x, y, 25, 12, LEAF))
    for i, shape in enumerate(s):
        shape['id'] = 'background' if i == 0 else f'r{i}'
    return {'width': 600, 'height': 600, 'revision': 3, 'theme': theme, 'subject': name, 'strokeWidth': 3, 'shapes': s}

def puzzle_scene(name, world):
    aquatic = name in ['fish', 'whale', 'octopus', 'turtle']
    return scene(name, 3 + world * 12 if aquatic else [0, 1, 2, 4][world], puzzle=True)

def shape_icon(kind, c):
    if kind == 'circle':
        s = [ellipse(20, 20, 160, 160, c)]
    elif kind == 'square':
        s = [rect(25, 25, 150, 150, c, 3)]
    elif kind == 'rectangle':
        s = [rect(15, 50, 170, 100, c, 3)]
    elif kind == 'triangle':
        s = [poly([[100, 18], [183, 182], [17, 182]], c)]
    elif kind == 'star':
        s = [star(100, 100, 87, c)]
    else:
        s = [path('M100 176 C79 161 16 120 17  60 C17 24 65 15 100  50 C135 15 183 24 183  60 C184 120 121 161 100 176 Z', c)]
    s[0]['color'] = c
    return {'width': 200, 'height': 200, 'revision': 3, 'strokeWidth': 2.5, 'shapes': s}
