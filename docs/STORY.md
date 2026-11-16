# The story

How a man who sold umbrellas became a fisherman, got hooked, and set off through seven waters after the thing that ate
his lunch. One page for every biome. The words live in `scripts/vf/vf_story.gd` (`CHAPTERS`).

## In the game

- **Menu → Story** shows one page at a time: a picture, a title and five short lines. The row of numbers turns to any
  page you have reached; a page still ahead says where it is and at which level.
- A page **opens by itself, once**, the first time you sail into its biome. The first page opens when the tutorial ends.
  If you are busy (a panel, Reel it in!, a Derby run), it waits in the Menu with a "new page!" note and a number on the
  Menu button.
- A page you have read stays yours after a prestige.
- Which pages were read is saved as `story` (a list of biome names). An older version of the game drops it, and then the
  pages simply open once more: no need to raise the save format for it.
- Check it: `Godot_console.exe --path . --resolution 1280x720 -- --capture=ABSOLUTE_DIR --story-test`
  (add `--touch --ui-dp=390` and `--resolution 1560x720` for a phone).

## The seven pages

1. **River · One day off.** He was not a fisherman. He sold umbrellas in a town where it never rained. On his one day
   off he rented a rowboat, a plastic rod and a tin of worms. He caught one small fish. It looked at him. He looked at
   it. It was the best day of his life. Then something as long as the river slid under the boat and ate his lunch. He
   should have gone home. He cast again.
2. **Volcanic · Just one more.** "One more cast," he said. That was four thousand casts ago. He sold the umbrellas. He
   bought a better rod. He told his mother it was a phase. When the river felt small, he followed the warm water to a
   sea that boils. The fish here come out cooked. He says he is only after the thing that ate his lunch. He is not only
   after the thing that ate his lunch.
3. **Ocean · It has a name.** In the harbour every sailor had a story about it, and not one of them had a photo. They
   call it the Leviathan. It swims through seven waters, and it has eaten a lunch in each. The merchant sold him a map:
   river, fire, sea, sky, stars, the strange seas, the bottom of everything. "Nobody has sailed them all," said the
   merchant. "Mostly because of the sky." He paid in fish. He would have paid in anything.
4. **Sky · Nobody told the boat.** Above the sea there is another sea, made of cloud, with islands that forgot to fall.
   Nobody had told the boat it couldn't sail up there. So it did. He caught a fish that was mostly weather, and a cold.
   One evening a shadow crossed the clouds from underneath, as long as a town. It was going up. So was he.
5. **Space · A long way from the river.** From here the river is a thin silver thread. He waves at it now and then.
   There is no up in space. The fish don't mind, and the worms float out of the tin looking pleased. He writes home:
   "Still fishing. Send socks." The post is slow. Last night something huge swam past the moon and left a wake in the
   stars. He reeled in, and followed.
6. **Alien · They know it here too.** Two moons, green water, and fish with more eyes than he has hooks. The locals
   have a word for the Leviathan. It means "the one who takes your lunch". They have a word for him too. It means "the
   one who won't go home". He asked them where it sleeps. Every one of them pointed down. All the way down.
7. **Abyss · The bottom of everything.** No light down here. Only his lamp, his line, and one very large eye. The
   Leviathan sleeps on everything it ever took: anchors, hats, a thousand rubber ducks, and a lunchbox with his name on
   it. He could have taken the lunchbox and gone home. He baited the hook instead. He caught it, of course. Then he let
   it go. What else would he chase tomorrow?

It ties in with what the game already has: the Leviathan is the boss that turns up in events (you catch it, and it is
back another day), the rubber ducks that float by ("Nobody knows where they come from") come from its pile, and the
captain already shouts "Hey! That's my lunch!" at the gull.

## The pictures (ChatGPT)

Until a page has its painting it shows the biome's own backdrop, so nothing is broken without them.

Seven pictures, one a page, **landscape 3:2 (1536x1024)**, plus one small icon for the Menu. Make them in the chat where
the enter-screen bay was made, or attach that picture (`tools/art/launcher_source_v2.png`) so the fisherman and the look
stay the same. Send this first:

```
I'm making 7 story pictures for my fishing game. Use exactly the same style and the same fisherman as the attached
picture: a bright, glossy 3D cartoon, soft warm light, round friendly shapes. The fisherman is a short, chubby,
cheerful man with a big brown moustache, a straw hat with a blue band, a light blue flowery shirt and tan shorts. He
has a wooden fishing rod with a red and white bobber, and a red cooler box that is his lunchbox.
The Leviathan is a gigantic whale, deep crimson red with a cream belly and a gentle face. It is enormous: the boat is
tiny next to it. It is never scary or hurt, it is funny.
Every picture: landscape 3:2, the important things in the middle (the edges may be cut off), and no words, letters or
numbers anywhere in the picture.
```

Then one message for each picture:

```
Picture 1, the river. A calm green river in a sunny forest, morning light. The fisherman sits in a small wooden rowboat
and proudly holds up one tiny silver fish; they look each other in the eye and he is delighted. A closed umbrella lies
in the boat. His red lunchbox stands open beside him. Under the boat, in the clear water, a huge dark red shape much
longer than the boat glides past, with one big friendly eye looking up at the lunchbox.
```

```
Picture 2, the volcano. A sea at the foot of a glowing volcano at dusk: orange light, steam rising from bubbling water.
The fisherman stands in his rowboat, a bit sunburnt, grinning, with far too many fishing rods and a big pile of fish in
the boat, and he is casting once more. The fish on his line comes out of the water already grilled, steaming, with
grill marks. Chalk tally strokes cover the side of the boat.
```

```
Picture 3, the ocean. A cheerful wooden harbour on a bright turquoise ocean at noon. A merchant behind a fish stall
hands the fisherman a rolled-open treasure map; the fisherman is thrilled and pays with a fish. The map shows seven
small drawings along a dotted path: a river wave, a flame, a sea wave, a cloud, a star, two moons and a dark deep hole.
Far out at sea, behind them, the gigantic crimson whale leaps over the horizon and nobody notices. Dolphins jump.
```

```
Picture 4, the sky. High above the world at sunset: a sea of pink and gold clouds with floating islands and waterfalls
pouring off them. The fisherman's small rowboat sails on the clouds as if they were water. He wears a red scarf and has
a red nose from a cold, and he fishes over the side. Just under the cloud surface a huge long shadow glides, and one
big fin breaks through the clouds.
```

```
Picture 5, space. Deep starry space with a big moon. The fisherman floats in his rowboat in zero gravity, wearing a
round glass fishbowl helmet over his straw hat, smiling. His fishing line drifts in curls and happy worms float out of
an open tin. Far below is a small blue planet with one thin silver river. The gigantic crimson whale swims past the
moon and leaves a sparkling wake of stars behind it.
```

```
Picture 6, the alien sea. A strange green sea under a purple sky with two moons, glowing plants on the shore. On a
small dock stand the fisherman and four small round friendly aliens with many eyes. All four aliens point straight
down into the water. The fisherman kneels at the edge with a lantern and looks down. Deep under the dock one enormous
eye glows faintly.
```

```
Picture 7, the bottom of the sea. The darkest sea floor, lit only by the fisherman's lantern. He sits in his rowboat
on the sea bed wearing an old brass diving helmet, calmly putting a worm on his hook, smiling. In front of him the
gigantic crimson whale lies curled up asleep on a mountain of things it has taken: anchors, hats, hundreds of yellow
rubber ducks, and right on top the fisherman's red lunchbox. One huge eye of the whale is half open and looks at him.
```

```
One more thing: an icon in the same style as the game's menu icons (thick, glossy, round, like a toy). A fat brown
leather storybook with a golden whale on its cover and a red ribbon bookmark, a little tilted. Square picture, plain
flat grey background, nothing else, no words.
```

Save them as `tools/art/story_source_1.png` to `story_source_7.png` (1 = river ... 7 = bottom of the sea) and the icon
as `tools/art/story_icon_source.png`. Then:

```bash
python tools/art/make_story.py
Godot_console.exe --headless --path . --import
```
