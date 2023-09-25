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
    CDC** p;
    
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
static MultiIcon	toom_faces; 
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

//status bar and faces
static CDC*		ST;
static CDC*		FACE00;
static CDC*		FACE0L;
static CDC*		FACE0R;
static CDC*		FACE10;
static CDC*		FACE1L;
static CDC*		FACE1R;
static CDC*		FACE20;
static CDC*		FACE2L;
static CDC*		FACE2R;
static CDC*		FACE30;
static CDC*		FACE3L;
static CDC*		FACE3R;
static CDC*		FACE40;
static CDC*		FACE4L;
static CDC*		FACE4R;


static Bool st_stopped = TRUE;

/*
**
**	FUNCTIONS
**
*/



static I64 st_palette = 0;




U0GrChar(CDC*dc,U8 ch,I64 x,I64 y,I64 scale)
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

U0 DrawPatch(CDC *to_dc, I64 sx,I64 sy,I64 ex,I64 ey, CDoomImage r) 
{
  F64 cx,cy;
  I64 i=0,j=0;
  I64 texture_w = r.w,texture_h = r.h; 
  I64 texture_l = r.left,texture_r = r.top;
  for(cy=sy;cy<=ey;cy++,i++) 
  {
    CDoomImageCol *curr = &r.col_offs[i];
    if(curr->rowstart==255)
    {
     if(i==texture_w)
     {
       i=0;
     }
     
    }

    for(cx=sx;cx<=ex;cx++,j++) 
    {
      if(j==curr->px_cnt)
      {
       j=0; 
      }
      to_dc->color=curr->data[j];
     // to_dc->color=GrPeek0(texture,point.x,point.y)
     // GrPlot3(to_dc,cx,cy,0);
      
    }
  }
}

U0 CopyPatch(CDC *to_dc,CDC*texture, I64 sx, I64 sy, I64 ex, I64 ey)
{
  F64 cx,cy;
  I64 i=0,j=0;
  
  for(cy=sy;cy<=ey;cy++) 
  {

    for(cx=sx;cx<=ex;cx++,j++) 
    {
     // to_dc->color=GrPeek0(texture,point.x,point.y)
     // GrPlot3(to_dc,cx,cy,0);
     // GrBlot(to_dc,0,0,texture);
      
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

        CDoomImage *ret = CAlloc(sizeof(CDoomImage));
        //ret = FramePtr("STBAR");        
        //CDC*texture = ReadDoomImage(ret);
        //GrChar(dc,ret->w,25,25,10);        
        GrBlot(gr.dc,0,SCREENHEIGHT-65,ST); //Read the image
        GrBlot(gr.dc,SCREENWIDTH/2-25,SCREENHEIGHT-64,toom_faces.p[toom_faces.inum]);
        //DrawPatch(dc,texture,0,0,SCREENWIDTH,SCREENHEIGHT,ret);
        //GrBlot(dc,500,100,texture);

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

U0 InitWidgets()
{
    toom_faces.p = MAlloc(sizeof(CDC)*40);

    // faces
    //STlib_initMultIcon(&w_faces,
//		       ST_FACESX,
//		       ST_FACESY,
//		       faces,
//		       &st_faceindex,
//		       &st_statusbaron);

}

U0 ST_ReadOnce(CDC*dc)
{
   if(st_firsttime ==FALSE)
   {
     //not efficent
     st_firsttime = TRUE;
     InitWidgets();
     CWadDirectory *wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STBAR",wad);  //Get the index and add it to the pointer
     ST = ReadDoomImage(wad->body+wad_dir->ptr); 

     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST01T",wad);  //Get the index and add it to the pointer
     FACE00 = ReadDoomImage(wad->body+wad_dir->ptr); 

     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST00T",wad);  //Get the index and add it to the pointer
     FACE0R = ReadDoomImage(wad->body+wad_dir->ptr); 

     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST02T",wad);  //Get the index and add it to the pointer
     FACE0L = ReadDoomImage(wad->body+wad_dir->ptr);   
     
     toom_faces.p[0]=FACE00;
     toom_faces.p[1]=FACE0R;
     toom_faces.p[2]=FACE0L;
     
   }

  
  
}

U0 ST_Key(U16 val)
{
   switch(val)
   {
     case 0: //release
       toom_faces.inum=0;
       break;
     case 1: //right
       toom_faces.inum=1;
       break;
     case 2: //left
       toom_faces.inum=2;
       break;

   }

}

U0 ST_Start(CDC*dc)
{
    st_statusbaron=TRUE;
    ST_ReadOnce(dc);
    ST_refresh(dc);
    //ST_createWidgets();
    //ST_refresh();

}

U0 ST_Exit()
{
  Free(toom_faces.p);
}

//ST_Start;
