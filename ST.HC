#include "Weapons.HC";
#define BG 4
#define FG 0


/*
**
** 	STATUSBARDATA/DEFINITIONS
**
*/


// Palette indices.
// For damage/bonus red-/gold-shifts
#define STARTREDPALS			1
#define STARTBONUSPALS			9
#define NUMREDPALS			8
#define NUMBONUSPALS			4
// Radiation suit, green shift.
#define RADIATIONPAL			13

// N/256*100% probability
//  that the normal face state will change
#define ST_FACEPROBABILITY		96

// For Responder
//#define ST_TOGGLECHAT			KEY_ENTER

// Location of status bar
#define ST_X				0
#define ST_X2				104
#define ST_FX  				143
#define ST_FY  				169

// Should be set to patch width
//  for tall numbers later on
//#define ST_TALLNUMWIDTH		(tallnum[0]->width)

// Number of status faces.
#define ST_NUMPAINFACES			5
#define ST_NUMSTRAIGHTFACES		3
#define ST_NUMTURNFACES			2
#define ST_NUMSPECIALFACES		3
//#define ST_FACESTRIDE \(ST_NUMSTRAIGHTFACES+ST_NUMTURNFACES+ST_NUMSPECIALFACES)

#define ST_NUMEXTRAFACES		2

//#define ST_NUMFACES \ (ST_FACESTRIDE*ST_NUMPAINFACES+ST_NUMEXTRAFACES)

#define ST_TURNOFFSET			(ST_NUMSTRAIGHTFACES)
#define ST_OUCHOFFSET			(ST_TURNOFFSET + ST_NUMTURNFACES)
#define ST_EVILGRINOFFSET		(ST_OUCHOFFSET + 1)
#define ST_RAMPAGEOFFSET		(ST_EVILGRINOFFSET + 1)
#define ST_GODFACE			(ST_NUMPAINFACES*ST_FACESTRIDE)
#define ST_DEADFACE			(ST_GODFACE+1)

#define ST_FACESX			143
#define ST_FACESY			168

#define ST_EVILGRINCOUNT		(2*TICRATE)
#define ST_STRAIGHTFACECOUNT		(TICRATE/2)
#define ST_TURNCOUNT		(1*TICRATE)
#define ST_OUCHCOUNT		(1*TICRATE)
#define ST_RAMPAGEDELAY		(2*TICRATE)

#define ST_MUCHPAIN			20


// Location and size of statistics,
//  justified according to widget type.
// Problem is, within which space? STbar? Screen?
// Note: this could be read in by a lump.
//       Problem is, is the stuff rendered
//       into a buffer,
//       or into the frame buffer?

// AMMO number pos.
#define ST_AMMOWIDTH			3	
#define ST_AMMOX			44
#define ST_AMMOY			171

// HEALTH number pos.
#define ST_HEALTHWIDTH			3	
#define ST_HEALTHX			90
#define ST_HEALTHY			171

// Weapon pos.
#define ST_ARMSX			111
#define ST_ARMSY			172
#define ST_ARMSBGX			104
#define ST_ARMSBGY			168
#define ST_ARMSXSPACE			12
#define ST_ARMSYSPACE			10

// Frags pos.
#define ST_FRAGSX			138
#define ST_FRAGSY			171	
#define ST_FRAGSWIDTH			2

// ARMOR number pos.
#define ST_ARMORWIDTH			3
#define ST_ARMORX			221
#define ST_ARMORY			171

// Key icon positions.
#define ST_KEY0WIDTH			8
#define ST_KEY0HEIGHT			5
#define ST_KEY0X			239
#define ST_KEY0Y			171
#define ST_KEY1WIDTH			ST_KEY0WIDTH
#define ST_KEY1X			239
#define ST_KEY1Y			181
#define ST_KEY2WIDTH			ST_KEY0WIDTH
#define ST_KEY2X			239
#define ST_KEY2Y			191

// Ammunition counter.
#define ST_AMMO0WIDTH			3
#define ST_AMMO0HEIGHT			6
#define ST_AMMO0X			288
#define ST_AMMO0Y			173
#define ST_AMMO1WIDTH			ST_AMMO0WIDTH
#define ST_AMMO1X			288
#define ST_AMMO1Y			179
#define ST_AMMO2WIDTH			ST_AMMO0WIDTH
#define ST_AMMO2X			288
#define ST_AMMO2Y			191
#define ST_AMMO3WIDTH			ST_AMMO0WIDTH
#define ST_AMMO3X			288
#define ST_AMMO3Y			185

// Indicate maximum ammunition.
// Only needed because backpack exists.
#define ST_MAXAMMO0WIDTH		3
#define ST_MAXAMMO0HEIGHT		5
#define ST_MAXAMMO0X 			314
#define ST_MAXAMMO0Y 			173
#define ST_MAXAMMO1WIDTH		ST_MAXAMMO0WIDTH
#define ST_MAXAMMO1X			314
#define ST_MAXAMMO1Y			179
#define ST_MAXAMMO2WIDTH		ST_MAXAMMO0WIDTH
#define ST_MAXAMMO2X			314
#define ST_MAXAMMO2Y			191
#define ST_MAXAMMO3WIDTH		ST_MAXAMMO0WIDTH
#define ST_MAXAMMO3X			314
#define ST_MAXAMMO3Y			185

// pistol
#define ST_WEAPON0X			110 
#define ST_WEAPON0Y			172

// shotgun
#define ST_WEAPON1X			122 
#define ST_WEAPON1Y			172

// chain gun
#define ST_WEAPON2X			134 
#define ST_WEAPON2Y			172

// missile launcher
#define ST_WEAPON3X			110 
#define ST_WEAPON3Y			181

// plasma gun
#define ST_WEAPON4X			122 
#define ST_WEAPON4Y			181

 // bfg
#define ST_WEAPON5X			134
#define ST_WEAPON5Y			181

// WPNS title
#define ST_WPNSX			109 
#define ST_WPNSY			191

 // DETH title
#define ST_DETHX			109
#define ST_DETHY			191

//Incoming messages window location
//UNUSED
// #define ST_MSGTEXTX	   (viewwindowx)
// #define ST_MSGTEXTY	   (viewwindowy+viewheight-18)
#define ST_MSGTEXTX			0
#define ST_MSGTEXTY			0
// Dimensions given in characters.
#define ST_MSGWIDTH			52
// Or shall I say, in lines?
#define ST_MSGHEIGHT			1

#define ST_OUTTEXTX			0
#define ST_OUTTEXTY			6

// Width, in characters again.
#define ST_OUTWIDTH			52 
 // Height, in lines. 
#define ST_OUTHEIGHT			1

//#define ST_MAPWIDTH	\ (strlen(mapnames[(gameepisode-1)*9+(gamemap-1)]))

//#define ST_MAPTITLEX \(SCREENWIDTH - ST_MAPWIDTH * ST_CHATFONTWIDTH)

#define ST_MAPTITLEY			0
#define ST_MAPHEIGHT			1

/*
**
** 	GLBLVARS
**
*/


// ST_Start() has just been called
static Bool st_firsttime = FALSE;
// used for timing
static U64 st_clock;

I64 st_randomnumber;
// whether left-side main status bar is active
static Bool st_statusbaron;
static I64 st_palette = 0;
// current face index, used by w_faces
static U16 st_faceindex = 0;

// used to execute ST_Init() only once
static I64 veryfirsttime = 1;
// used to use appopriately pained face
static I64 st_oldhealth = -1;

// main bar left
static CDoomImage *sbar;


/*
**
** 	CLASSES
**
*/


class STNum 
{
    // upper right-hand corner
    //  of the number (right-justified)
    I64	x;
    I64 y;

    // max # of digits in number
    I64 width;    

    // last number value
    I64 oldnum;
    
    // pointer to current value
    I64 *num;

    // pointer to boolean stating
    //  whether to update number
    Bool *on;

    // list of patches for 0-9
    CDoomImage**	p;

    // user data
    I64 data;    
};

class PercentWidget
{
    //number information
    STNum n;
    //percent graphic
    CDoomImage *p;
};


// Multiple Icon widget
class MultiIcon
{
     // center-justified location of icons
    I64 x;
    I64 y;

    // last icon number
    I64 oldinum;

    // pointer to current icon
    I64 *inum;

    // pointer to boolean stating
    //  whether to update icon
    Bool *on;

    // list of icons
    CDoomImage** p;
    
    // user data
    I64 data;
    
};




// Binary Icon widget

class BinaryIcon
{
    // center-justified location of icon
    I64 x;
    I64 y;

    // last icon value
    I64 oldval;

    // pointer to current icon status
    Bool *val;

    // pointer to boolean
    //  stating whether to update icon
    Bool *on;  


    CDoomImage* p;	// icon
    I64 data;   // user data
    
};


/*
**
** 	WIDGETS
**
*/


// health widget
static PercentWidget	w_health;
// arms background
static BinaryIcon	w_armsbg; 
// weapon ownership widgets
static MultiIcon	w_arms[6];
// face status widget
static MultiIcon	w_faces; 
// keycard widgets
static MultiIcon	w_keyboxes[3];
// armor widget
static PercentWidget	w_armor;
// ammo widgets
static STNum		w_ammo[4];
// max ammo widgets
static STNum		w_maxammo[4]; 
// holds key-type for each key box on bar
static I64 		keyboxes[3]; 


static Bool st_stopped = TRUE;

/*
**
**	FUNCTIONS
**
*/


U0 ST_initData()
{

    I64 i;

    st_firsttime = TRUE;
    //plyr = &players[consoleplayer];

    st_clock = 0;
    //st_chatstate = StartChatState;
    //st_gamestate = FirstPersonState;

    st_statusbaron = TRUE;
    //st_oldchat = st_chat = false;
    //st_cursoron = false;

    st_faceindex = 0;
    st_palette = -1;

    st_oldhealth = -1;

    //for (i=0;i<NUMWEAPONS;i++)
//	oldweaponsowned[i] = plyr->weaponowned[i];

    for (i=0;i<3;i++)
	keyboxes[i] = -1;

    //STlib_init();

}

U0 ST_Ticker()
{
    st_clock++;
    st_randomnumber = RandI64;
    //ST_updateWidgets();
    //st_oldhealth = plyr->health;
}

static I64 st_palette = 0;

U0 ST_drawWidgets(Bool refresh)
{
    I64	i;

    // used by w_arms[] widgets
    //st_armson = st_statusbaron && !deathmatch;

    // used by w_frags widget
    //st_fragson = deathmatch && st_statusbaron; 
/*
    STlib_updateNum(&w_ready, refresh);

    for (i=0;i<4;i++)
    {
	STlib_updateNum(&w_ammo[i], refresh);
	STlib_updateNum(&w_maxammo[i], refresh);
    }

    STlib_updatePercent(&w_health, refresh);
    STlib_updatePercent(&w_armor, refresh);

    STlib_updateBinIcon(&w_armsbg, refresh);

    for (i=0;i<6;i++)
	STlib_updateMultIcon(&w_arms[i], refresh);

    STlib_updateMultIcon(&w_faces, refresh);

    for (i=0;i<3;i++)
	STlib_updateMultIcon(&w_keyboxes[i], refresh);

    STlib_updateNum(&w_frags, refresh);
*/
}

U0 ST_doRefresh()
{

    st_firsttime = FALSE;

    // draw status bar background to off-screen buff
    //ST_refreshBackground();

    // and refresh all widgets
    ST_drawWidgets(TRUE);

}

U0 ST_diffDraw()
{
    // update all widgets
    ST_drawWidgets(FALSE);
}

U0 ST_Drawer (Bool fullscreen, Bool refresh)
{
  
    //st_statusbaron = (!fullscreen) ;//|| automapactive;
    st_firsttime = st_firsttime || refresh;

    // Do red-/gold-shifts from damage/items
    //ST_doPaletteStuff();

    // If just after ST_Start(), refresh all
    if (st_firsttime){ 
      ST_doRefresh();
    }
    // Otherwise, update as little as possible
    else {
      ST_diffDraw();
    }

}

U0 ST_loadGraphics()
{

    //I64 i,j,facenum;
    //faceback = W_CheckNumForName(namebuf, wad);

    // status bar background bits

        
    //U8 namebuf[9];
}

U0 ST_loadData()
{
    //lu_palette = W_GetNumForName("PLAYPAL");
    //ST_loadGraphics();

}

    // Load the numbers, tall and short -- source code for STloadGraphics
/*
    for (i=0;i<10;i++)
    {
	StrPrint(namebuf, "STTNUM%d", i);
	tallnum[i] = (CDoomImage *) W_CacheLumpName(namebuf, PU_STATIC);

	StrPrint(namebuf, "STYSNUM%d", i);
	shortnum[i] = (CDoomImage *) W_CacheLumpName(namebuf, PU_STATIC);
    }

    // Load percent key.
    //Note: why not load STMINUS here, too?
    tallpercent = (CDoomImage *) W_CacheLumpName("STTPRCNT", PU_STATIC);

    // key cards
    for (i=0;i<NUMCARDS;i++)
    {
	sprintf(namebuf, "STKEYS%d", i);
	keys[i] = (CDoomImage *) W_CacheLumpName(namebuf, PU_STATIC);
    }

    // arms background
    armsbg = (CDoomImage *) W_CacheLumpName("STARMS", PU_STATIC);

    // arms ownership widgets
    for (i=0;i<6;i++)
    {
	sprintf(namebuf, "STGNUM%d", i+2);

	// gray #
	arms[i][0] = (CDoomImage *) W_CacheLumpName(namebuf, PU_STATIC);

	// yellow #
	arms[i][1] = shortnum[i+2]; 
    }

    // face backgrounds for different color players
    sprintf(namebuf, "STFB%d", consoleplayer);
    faceback = (CDoomImage *) W_CacheLumpName(namebuf, PU_STATIC);

    // status bar background bits
    sbar = (CDoomImage *) W_CacheLumpName("STBAR", PU_STATIC);

    // face states
    facenum = 0;
    for (i=0;i<ST_NUMPAINFACES;i++)
    {
	for (j=0;j<ST_NUMSTRAIGHTFACES;j++)
	{
	    sprintf(namebuf, "STFST%d%d", i, j);
	    faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
	}
	sprintf(namebuf, "STFTR%d0", i);	// turn right
	faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
	sprintf(namebuf, "STFTL%d0", i);	// turn left
	faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
	sprintf(namebuf, "STFOUCH%d", i);	// ouch!
	faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
	sprintf(namebuf, "STFEVL%d", i);	// evil grin ;)
	faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
	sprintf(namebuf, "STFKILL%d", i);	// pissed off
	faces[facenum++] = W_CacheLumpName(namebuf, PU_STATIC);
    }
    faces[facenum++] = W_CacheLumpName("STFGOD0", PU_STATIC);
    faces[facenum++] = W_CacheLumpName("STFDEAD0", PU_STATIC);

}

}

void ST_unloadGraphics(void)
{

    int i;

    // unload the numbers, tall and short
    for (i=0;i<10;i++)
    {
	Z_ChangeTag(tallnum[i], PU_CACHE);
	Z_ChangeTag(shortnum[i], PU_CACHE);
    }
    // unload tall percent
    Z_ChangeTag(tallpercent, PU_CACHE); 

    // unload arms background
    Z_ChangeTag(armsbg, PU_CACHE); 

    // unload gray #'s
    for (i=0;i<6;i++)
	Z_ChangeTag(arms[i][0], PU_CACHE);
    
    // unload the key cards
    for (i=0;i<NUMCARDS;i++)
	Z_ChangeTag(keys[i], PU_CACHE);

    Z_ChangeTag(sbar, PU_CACHE);
    Z_ChangeTag(faceback, PU_CACHE);

    for (i=0;i<ST_NUMFACES;i++)
	Z_ChangeTag(faces[i], PU_CACHE);

    // Note: nobody ain't seen no unloading
    //   of stminus yet. Dude.
    

}

void ST_unloadData(void)
{
    ST_unloadGraphics();
}



*/
U0 ST_createWidgets()
{

    I64 i;
    /*
    // ready weapon ammo
    STlib_initNum(&w_ready,
		  ST_AMMOX,
		  ST_AMMOY,
		  tallnum,
		  &plyr->ammo[weaponinfo[plyr->readyweapon].ammo],
		  &st_statusbaron,
		  ST_AMMOWIDTH );

    // the last weapon type
    w_ready.data = plyr->readyweapon; 

    // health percentage
    STlib_initPercent(&w_health,
		      ST_HEALTHX,
		      ST_HEALTHY,
		      tallnum,
		      &plyr->health,
		      &st_statusbaron,
		      tallpercent);

    // arms background
    STlib_initBinIcon(&w_armsbg,
		      ST_ARMSBGX,
		      ST_ARMSBGY,
		      armsbg,
		      &st_notdeathmatch,
		      &st_statusbaron);

    // weapons owned
    for(i=0;i<6;i++)
    {
	STlib_initMultIcon(&w_arms[i],
			   ST_ARMSX+(i%3)*ST_ARMSXSPACE,
			   ST_ARMSY+(i/3)*ST_ARMSYSPACE,
			   arms[i], (int *) &plyr->weaponowned[i+1],
			   &st_armson);
    }

    // frags sum
    STlib_initNum(&w_frags,
		  ST_FRAGSX,
		  ST_FRAGSY,
		  tallnum,
		  &st_fragscount,
		  &st_fragson,
		  ST_FRAGSWIDTH);

    // faces
    STlib_initMultIcon(&w_faces,
		       ST_FACESX,
		       ST_FACESY,
		       faces,
		       &st_faceindex,
		       &st_statusbaron);

    // armor percentage - should be colored later
    STlib_initPercent(&w_armor,
		      ST_ARMORX,
		      ST_ARMORY,
		      tallnum,
		      &plyr->armorpoints,
		      &st_statusbaron, tallpercent);

    // keyboxes 0-2
    STlib_initMultIcon(&w_keyboxes[0],
		       ST_KEY0X,
		       ST_KEY0Y,
		       keys,
		       &keyboxes[0],
		       &st_statusbaron);
    
    STlib_initMultIcon(&w_keyboxes[1],
		       ST_KEY1X,
		       ST_KEY1Y,
		       keys,
		       &keyboxes[1],
		       &st_statusbaron);

    STlib_initMultIcon(&w_keyboxes[2],
		       ST_KEY2X,
		       ST_KEY2Y,
		       keys,
		       &keyboxes[2],
		       &st_statusbaron);

    // ammo count (all four kinds)
    STlib_initNum(&w_ammo[0],
		  ST_AMMO0X,
		  ST_AMMO0Y,
		  shortnum,
		  &plyr->ammo[0],
		  &st_statusbaron,
		  ST_AMMO0WIDTH);

    STlib_initNum(&w_ammo[1],
		  ST_AMMO1X,
		  ST_AMMO1Y,
		  shortnum,
		  &plyr->ammo[1],
		  &st_statusbaron,
		  ST_AMMO1WIDTH);

    STlib_initNum(&w_ammo[2],
		  ST_AMMO2X,
		  ST_AMMO2Y,
		  shortnum,
		  &plyr->ammo[2],
		  &st_statusbaron,
		  ST_AMMO2WIDTH);
    
    STlib_initNum(&w_ammo[3],
		  ST_AMMO3X,
		  ST_AMMO3Y,
		  shortnum,
		  &plyr->ammo[3],
		  &st_statusbaron,
		  ST_AMMO3WIDTH);

    // max ammo count (all four kinds)
    STlib_initNum(&w_maxammo[0],
		  ST_MAXAMMO0X,
		  ST_MAXAMMO0Y,
		  shortnum,
		  &plyr->maxammo[0],
		  &st_statusbaron,
		  ST_MAXAMMO0WIDTH);

    STlib_initNum(&w_maxammo[1],
		  ST_MAXAMMO1X,
		  ST_MAXAMMO1Y,
		  shortnum,
		  &plyr->maxammo[1],
		  &st_statusbaron,
		  ST_MAXAMMO1WIDTH);

    STlib_initNum(&w_maxammo[2],
		  ST_MAXAMMO2X,
		  ST_MAXAMMO2Y,
		  shortnum,
		  &plyr->maxammo[2],
		  &st_statusbaron,
		  ST_MAXAMMO2WIDTH);
    
    STlib_initNum(&w_maxammo[3],
		  ST_MAXAMMO3X,
		  ST_MAXAMMO3Y,
		  shortnum,
		  &plyr->maxammo[3],
		  &st_statusbaron,
		  ST_MAXAMMO3WIDTH);
  */

}



U0GrChar(CDC*dc=gr.dc,U8 ch,I64 x,I64 y,I64 scale)
{
  I64 i,j,k=0;
  for(i=0;i<FONT_HEIGHT;i++){
    for(j=0;j<FONT_WIDTH;j++){
      if(Bt(&text.font[ch],k++)){
        GrRect(dc,x+j*scale,y+i*scale,scale,scale);
      }
    }
  }
}

U0 ST_refreshBackground()
{

    if (!st_statusbaron)
    {
        //wad_dir=wad->body+wad->directory_ptr;
        //wad_dir+=W_CheckNumForName("F_START",wad);
        CDoomGr *ret=CAlloc(sizeof(CDoomGr));
        //TODO: need palette
	CWadDirectory *wad_dir;
        wad_dir=wad->body+wad->directory_ptr;
        wad_dir+=W_CheckNumForName("STBAR",wad);
	ReadDoomImage(wad,wad->body+wad_dir->ptr, ret->palette);
	//V_CopyRect(ST_X, 0, BG, ST_WIDTH, ST_HEIGHT, ST_X, ST_Y, FG);
    }

}

U0 ST_refresh()
{
  ST_refreshBackground();
}

U0 Text()
{
//dc->color=WHITE;
//GrChar(dc,x,y,SCRN_SCALE/2,5);
}


U0 ST_Stop ()
{
    if (st_stopped)
	return;

    //I_SetPalette (W_CacheLumpNum (lu_palette, PU_CACHE));

    st_stopped = TRUE; 
}

U0 ST_Start ()
{
    if (!st_stopped)
	ST_Stop();

    ST_initData();
    ST_createWidgets();
    ST_refresh();
    st_stopped = FALSE;

}

}

U0 ST_Init ()
{
    veryfirsttime = 0;
   // ST_loadData();
   // screens[4] = (byte *) Z_Malloc(ST_WIDTH*ST_HEIGHT, PU_STATIC, 0);
}
//ST_Start;
DCFill;