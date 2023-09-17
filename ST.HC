//#include "Weapons.HC";
#define BG 4
#define FG 0
#define SCREENWIDTH 640
#define SCREENHEIGHT 480

/*
**
** 	STATUSBARDATA/DEFINITIONS
**
*/
// For Responder
//#define ST_TOGGLECHAT			KEY_ENTER

// Location of status bar
#define ST_X				0
#define ST_X2				104
#define ST_FX  				143
#define ST_FY  				169

/*
**
** 	GLBLVARS
**
*/


// ST_Start() has just been called
static Bool st_firsttime = FALSE;
// whether left-side main status bar is active
static Bool st_statusbaron;
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

    // draw status bar background to off-screen buff
    //ST_refreshBackground();

    // and refresh all widgets
    ST_drawWidgets(TRUE);

}






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

U0 DrawPatch(CDC *to_dc,CDC*texture, I64 sx,I64 sy,I64 ex,I64 ey) 
{
  F64 cx,cy;
  I64 texture_x,texture_y; 
  for(cx=sx;cx<=ex;cx++) 
  {
    for(cy=sy;cy<=ey;cy++) 
    {
      //if(0<=at_y-h<GR_HEIGHT) 
      //{
      //  texture_y=Lerp(cy/h,0,texture->height);
        to_dc->color=BLACK;//GrPeek0(texture,cx,cy);
        GrPlot3(to_dc,cx,cy,0);
      //}
    }
  }
}


U0 ST_refreshBackground(CDC*dc)
{
    CDoomImageCol *curr = NULL;
    if (st_statusbaron)
    {
        //wad_dir=wad->body+wad->directory_ptr;
        //wad_dir+=W_CheckNumForName("F_START",wad);
        //CDoomGr *ret=CAlloc(sizeof(CDoomGr));
        CDoomImage *ret =CAlloc(sizeof(CDoomImage));
        ret=FramePtr("STBAR");
        //ret->palette=LoadPLAYPALFromLump(W_GetLumpPtrFromName("PLAYPAL",wad));
        CDC*texture = ReadDoomImage(wad,ret,dgr->palette);

        DrawPatch(dc,texture,0,0,SCREENWIDTH,SCREENHEIGHT);

        /*
        I16 x;
        I16 y = ret->top;
        I16 w = ret->w;
        I16 h = ret->h;
        I64 desttop = SCREENHEIGHT+y*SCREENWIDTH+x;
        I64 col = 0,count=0;
        U8* source,dest;
        for(x=ret->left;col<w;x++,col++,desttop++) 
        {
          curr = ret+(U8*)ret->col_offs[col];
          while(curr->rowstart!=255)
          {
           source = col(U8*)+3;
           dest = desttop +curr->rowstart*SCREENWIDTH;
           count= curr->px_cnt;
           while(count>=0)
           {
             dc->color=GrPeek0(ret,count,col);
	     GrPlot(dc,x,dest);
             count--;
             // *dest=*source++;
             //dest+=SCREENWIDTH;
           }
           curr= curr(U8*)+curr->px_cnt+ 4 ;
          }
          //h=Lerp((x-ST_X)/(SCREENWIDTH-ST_X),sh,eh);
          //texture_x=Lerp((x-ST_X)/(SCREENWIDTH-ST_X),start_seg,end_seg)%ret->width;
          //at_y=Lerp((cx-sx)/(ex-sx),sy,ey); 
        }*/

	//CWadDirectory *wad_dir;
        //wad_dir=wad->body+wad->directory_ptr;
        //wad_dir+=W_CheckNumForName("STBAR",wad);
	//gr = ReadDoomImage(wad,wad->body+wad_dir->ptr, ret->palette);

	//V_CopyRect(ST_X, 0, BG, ST_WIDTH, ST_HEIGHT, ST_X, ST_Y, FG);
    }

}

U0 ST_refresh(CDC*dc)
{
  ST_refreshBackground(dc);
}


U0 ST_Start (CDC*dc)
{
    st_statusbaron=TRUE;
    ST_refresh(dc);
    //ST_createWidgets();
    //ST_refresh();

}

//ST_Start;
