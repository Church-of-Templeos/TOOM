# TOOM
A TempleOS source port of the DOOM engine

![TITLEPICTOOM](https://github.com/austings/TOOM/blob/4e6dfe75987af22f88d2dd718f2151d9dae820ae/TITLEPICTOOM.png)

# Install
Run the following command to copy the game to your C drive. Then play the game with Load.HC

>#include "T:/Install.HC";
>
>Cd("C:/Home/TOOM");
>
>#include "Load.HC";


# Controls

Mouse to look around

Left mouse button to fire

Arrow keys or WASD to move around

0-9 or mousewheel to change weapons

Spacebar to activate buttons and doors

Tab to open the map

# Development 
##  Dithering
In TOOM all the pixels are acutally "2x2" pixels this allows for dithering. This means in many places in source code you will see things like 
```
tx=x*2; //*2 for dithered pixel
```
The reason I use dithering is that in TempleOS there are 16 colors,but If you display 2 tiny pixels next to each other they "mix" effectively making a new color.

When loading the graphics,I turn the colors from the `PLAYPAL` lump into 2*2 dither pixels(See `U8 *DitherPalette(CRGB *data)` in [DoomGr.HC](DoomGr.HC)). This works by taking the "distance" of the differnces of the colors(triangle distance). I choose the "closest" distance once I average the 2 16-color pixels

I pass the wad data( after being processed from `ReadDoomImage␅`) to `PaletteizeImage␅` to make a dithered image(`ReadDoomImage` has the 256 color palette data).

### Lighting.
This game has lighting in it. There main lighting function is `LookupLighting␅(U16 dith,I64 light,F64 distance,Bool god_mode=FALSE␅)`. This will take a dithered pixel and transform it based on distance and god_mode which is a powerup. It returns a `U32`. The upper 16 bits are the bottom dithered pixel pair,and the low are the upper pair

## Collision
Collision mainly uses [Intersect.HC](Intersect.HC) and [Collision.HC](Collision.HC).
`Intersect.HC` comes with `Bool PlaneIntersect(CD2 *dst,CD2 *a,CD2 *b,CD2 *a2,CD2 *b2,Bool check=TRUE)`. This does what you think it does probably.

The real secret sauce is in `Collision.HC`. Collision in mainly handled in `CDoomLinedef *MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 tallness,F64 radius=64.,F64 cur_height=0.,I64 flags=COLLISF_SLIDE,CFifoI64 *walked_over_hot=NULL,CDoomThing *exclude=NULL,CDoomThing **_hit_thing=NULL)␅`.

The usage of this function is this:
  * flags 
	  * COLLISF_SLIDE
		  * Enables "slding" agianst wall
	  * COLLISF_NO_DROP
		  * Forbids enemies falling off ledges
	* COLLISF_NO_HIT_THING
		* Dont hit `exclude`
	* many more
* walked_over_hot. A `CFifoI64` of linedefs that were walked over
## Internals of Collision.HC
At the heard of the collision `MoveInLevel` is the blockmap. In Doom the blockmap is a list of linedefs in a grid. I first check which walls in a blockmap and it's neighbors cannot be passed. If I pass a line that Is un-passable I reject the entire move(for now)

I also have a `CMoveStep` class that is used for stepping along steps on stairs(a single wall above `STEP_HEIGHT` is marked as impassable)

If we hit a wall I go backwards to find a "good" position. The most nefarious part of it is in `COLLSIF_SLIDE`. Becuase **if you walk into a wall ,there may be cracks in it**,we need to differentiate between the crack and the wall,so I use the **normal** of each offending wall's vector with `NormalScore` and then I walk along the  normal of that vector. If we cant go the whole distance I try again 3 times see `recur_depth`.

Also **BE SURE TO UPDATE THE BLOCKMAP/SECTOR THING DATA IF MOVING THINGS**,a helper for this is in `MoveInLevelFinal` in [Collision.HC](Collision.HC).

## Enemy AI
The enemy AI in this game uses a state machine. Each state has a time,function pointer,and animation_frames. I initialize the states in `LoadMonsterInfo`. The states(and monster properties) look something like this.
 ```c
  t=doom_thing_types[0xbb9];
  UH("impidle",t->_idle_frames=GenerateCacheFrames(t,"AB"));
  UH("impchase",t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD"));
  UH("impmelee",t->_melee_frames=GenerateCacheFrames(t,"EFG"));
  UH("impatk",t->_attack_frames=GenerateCacheFrames(t,"EFG"));
  UH("imphurt",t->_hurt_frames=GenerateCacheFrames(t,"HH"));
  UH("impdie",t->_dying_frames=GenerateCacheFrames(t,"IJKLM"));
  UH("impohfuck",t->_gib_frames=GenerateCacheFrames(t,"NOPQRSTU"));
  t->pain_time=1/35.*4;
  t->reaction_time=1/35.*8;
  t->health=60;
  t->speed=8.;
  t->mass=100;
  t->damage=3;
  t->pain_chance=200./255;
    AddState(t->spawn_state="IMP.S_POSS_STND",10,t->_idle_frames,&Look,"IMP.S_POSS_STND");
  AddState(t->see_state="IMP.S_POSS_RUN",0,t->_chase_frames,&Chase,"IMP.S_POSS_RUN");
  AddState(t->missile_state="IMP.S_POSS_ATK1",t->reaction_time*4,t->_idle_frames,&FaceTarget,"IMP.S_POSS_ATK2");
  AddState("IMP.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&TroopAttack,"IMP.S_POSS_RUN");
  AddState(t->pain_state="IMP.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"IMP.S_POSS_RUN");
  AddState(t->death_state="IMP.S_POSS_DIE",STATE_NO_REPEAT,t->_dying_frames,&Fall,"ST_NULL");
  AddState(t->gib_state="IMP.S_POSS_GIB",STATE_NO_REPEAT,t->_gib_frames,&XFall,"ST_NULL");
  ```
  Here I use `GenerateCacheFrames` to make a frames,and `UH`(which be elaborated in the Save/Load section) to make the animation frames. And them I add the state's via `AddState`. The states are named by string and looked up in the hash-table.
  There are 2 special state times called `STATE_UNTIL_ANIM_DONE` and `STATE_NO_REPEAT`. The first is used for forcing an animation to finish,and `STATE_NO_REPEAT` is used for death states that dont repeat ever.

## Thinkers
`MonsterThinker␅` is the thinker that will switch states for the monsters,but `CDoomThinkerBase` does much more than that,it controls things like stairs,doors,floors and more.
To add a thinker,use `AddThinker(CDoomLevel*,U8 (*func_ptr)(CDoomLevel *,U8 *slef),U8 *class_name)`. ***`class_name` must be provided for saving the game**.

When you are done with a thinker(from the thinker callback) do this:
```c
U0 Thinker(CDoomLevel *,U8 *self) {
//Do Somthing
  QueRem(self);
  Free(self);
}
```

## Interactive world
See [World.HC](World.HC). `action_sector_types` is incorrectly named but easily can be fixed. These are used from the `special_type` feild in `CDoomLinedef`. You activate them via `TriggerLinedef`.

## The Rest?
Read the source code. The above was most of the overview. The above was meant to give you an overview,not a comprehensive guide to reading the source code.
