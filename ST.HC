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
    I64 num;

    // pointer to boolean stating
    //  whether to update number
    Bool on;

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
    I64 inum;

    // pointer to boolean stating
    //  whether to update icon
    Bool on;

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
// face status widget
static MultiIcon	toom_faces; 
// armor widget
static PercentWidget	w_armor;
// ammo widgets
static STNum		w_ammo[4];
// max ammo widgets
static STNum		w_maxammo[4]; 
// holds key-type for each key box on bar
static I64 		keyboxes[3]; 
// weapon anims
static MultiIcon	weapons;

//weapons
static CDC*		PUNCH;
static CDC*		PUNCH1;
static CDC*		PUNCH2;
static CDC*		PUNCH3;
static CDC*		PISTOL;
static CDC*		PISTOLU;
static CDC*		PISTOL1;
static CDC*		PISTOL2;
static CDC*		PISTOL3;
static CDC*		PISTOLF;
static CDC*		SHOTGUN;
static CDC*		SHOTGUN1;
static CDC*		SHOTGUN2;
static CDC*		SHOTGUN3;
static CDC*		SHOTGUNF1;
static CDC*		SHOTGUNF2;
static CDC*		CHAINGUN;
static CDC*		CHAINGUN1;
static CDC*		CHAINGUNF1;
static CDC*		CHAINGUNF2;
static CDC*		MISSILELAUNCHER;
static CDC*		MISSILELAUNCHER1;
static CDC*		MISSILELAUNCHERF1;
static CDC*		MISSILELAUNCHERF2;
static CDC*		MISSILELAUNCHERF3;
static CDC*		MISSILELAUNCHERF4;
static CDC*		CHAINSAW;
static CDC*		CHAINSAW1;
static CDC*		CHAINSAW2;
static CDC*		CHAINSAW3;
static CDC*		PLASMAGUN;
static CDC*		PLASMAGUN1;
static CDC*		PLASMAGUNF1;
static CDC*		PLASMAGUNF2;
static CDC*		BFG;
static CDC*		BFG1;
static CDC*		BFG2;
static CDC*		BFGF1;
static CDC*		BFGF2;

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




U0GrChar(CDC*dc,U8 ch,I64 x,I64 y,I64 scale)
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
        if(weapons.data>0)
        {//draw weapons flash
         I16 xmodify=0;
         if(weapons.inum<10&&weapons.inum>3)//pistol
         {
         GrBlot(gr.dc,weapons.x+62,weapons.y-24,
                     weapons.p[weapons.data]);
         }
         if(weapons.inum>=10&&weapons.inum<16)//shotgun
         {
         GrBlot(gr.dc,weapons.x+38,weapons.y-32,
                     weapons.p[weapons.data]);
         }
         if(weapons.inum>=16&&weapons.inum<20&&weapons.on==TRUE)//chaingun
         {
         GrBlot(gr.dc,weapons.x+32,weapons.y-32,
                     weapons.p[weapons.data]);
         }
         if(weapons.inum>=20&&weapons.inum<26)//missile launcher 1
         {
          if(weapons.data>22)
             xmodify=-16;
          if(weapons.data>23)
             xmodify=-28;
          if(weapons.data>24)
             xmodify=-38;  
         GrBlot(gr.dc,weapons.x+42+xmodify,weapons.y-32+xmodify,
                     weapons.p[weapons.data]);
         }
         if(weapons.inum>=34&&weapons.inum<38)//bfg
         {
          if(weapons.data==38)
             xmodify=-54;
          
         GrBlot(gr.dc,weapons.x+72+xmodify,weapons.y-16+xmodify,
                     weapons.p[weapons.data]);
         }
        }
        
       
	GrBlot(gr.dc,weapons.x,weapons.y,
                     weapons.p[weapons.inum]);//weapon
        

        
        
        GrBlot(gr.dc,0,SCREENHEIGHT-64,ST); //Read the ST
        GrBlot(gr.dc,SCREENWIDTH/2-25,SCREENHEIGHT-64,
                      toom_faces.p[toom_faces.inum]);//faces
        
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
    weapons.p = MAlloc(sizeof(CDC)*39);

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

     //STATUS BARS
     CWadDirectory *wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STBAR",wad);  //Get the index and add it to the pointer
     ST = ReadDoomImage(wad->body+wad_dir->ptr); 
 
     //FACES
     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST01T",wad);  //Get the index and add it to the pointer
     FACE00 = ReadDoomImage(wad->body+wad_dir->ptr); 

     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST00T",wad);  //Get the index and add it to the pointer
     FACE0R = ReadDoomImage(wad->body+wad_dir->ptr); 

     wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored
     wad_dir+=W_CheckNumForName("STFST02T",wad);  //Get the index and add it to the pointer
     FACE0L = ReadDoomImage(wad->body+wad_dir->ptr);   


     //WEAPONS
     //PUNCH

     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PUNGA0",wad);  
     PUNCH = ReadDoomImage(wad->body+wad_dir->ptr);     
     wad_dir=wad->body+wad->directory_ptr; 
     wad_dir+=W_CheckNumForName("PUNGB0",wad);  
     PUNCH1 = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PUNGC0",wad);  
     PUNCH2 = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PUNGD0",wad);  
     PUNCH3 = ReadDoomImage(wad->body+wad_dir->ptr);   //4 sprites
   
     //PISTOL
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISGA0",wad);  
     PISTOL = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISGE0",wad);  
     PISTOLU = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISGB0",wad);  
     PISTOL1 = ReadDoomImage(wad->body+wad_dir->ptr);
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISGC0",wad);  
     PISTOL2 = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISGD0",wad);  
     PISTOL3 = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PISFA0",wad);  
     PISTOLF = ReadDoomImage(wad->body+wad_dir->ptr);   //6 sprites
    
     //SHOTGUN   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTGA0",wad);  
     SHOTGUN = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTGB0",wad);  
     SHOTGUN1 = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTGC0",wad);  
     SHOTGUN2 = ReadDoomImage(wad->body+wad_dir->ptr);   
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTGD0",wad);  
     SHOTGUN3 = ReadDoomImage(wad->body+wad_dir->ptr);         
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTFA0",wad);  
     SHOTGUNF1 = ReadDoomImage(wad->body+wad_dir->ptr); 
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SHTFB0",wad);  
     SHOTGUNF2 = ReadDoomImage(wad->body+wad_dir->ptr); //6 sprites      
     
     //CHAINGUN
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("CHGGA0",wad);  
     CHAINGUN = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("CHGGB0",wad);  
     CHAINGUN1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("CHGFA0",wad);  
     CHAINGUNF1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("CHGFB0",wad);  
     CHAINGUNF2 = ReadDoomImage(wad->body+wad_dir->ptr); //4 sprites      

     //MISSILELAUNCHER
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISGA0",wad);  
     MISSILELAUNCHER = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISGB0",wad);  
     MISSILELAUNCHER1 = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISFA0",wad);  
     MISSILELAUNCHERF1 = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISFB0",wad);  
     MISSILELAUNCHERF2 = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISFC0",wad);  
     MISSILELAUNCHERF3 = ReadDoomImage(wad->body+wad_dir->ptr);      
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("MISFD0",wad);  
     MISSILELAUNCHERF4 = ReadDoomImage(wad->body+wad_dir->ptr); //6 sprites      

     //CHAINSAW
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SAWGA0",wad);  
     CHAINSAW = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SAWGB0",wad);  
     CHAINSAW1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SAWGC0",wad);  
     CHAINSAW2 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("SAWGD0",wad);  
     CHAINSAW3 = ReadDoomImage(wad->body+wad_dir->ptr);  //4 sprites     

     //PLASMAGUN
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PLSGA0",wad);  
     PLASMAGUN = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PLSGB0",wad);  
     PLASMAGUN1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PLSFA0",wad);  
     PLASMAGUNF1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("PLSFB0",wad);  
     PLASMAGUNF2 = ReadDoomImage(wad->body+wad_dir->ptr);  //4 sprites     

     //BFG
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("BFGGA0",wad);  
     BFG = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("BFGGB0",wad);  
     BFG1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("BFGGC0",wad);  
     BFG2 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("BFGFA0",wad);  
     BFGF1 = ReadDoomImage(wad->body+wad_dir->ptr);       
     wad_dir=wad->body+wad->directory_ptr;  
     wad_dir+=W_CheckNumForName("BFGFB0",wad);  
     BFGF2 = ReadDoomImage(wad->body+wad_dir->ptr);   //5 sprites    


     toom_faces.p[0]=FACE00;
     toom_faces.p[1]=FACE0R;
     toom_faces.p[2]=FACE0L;

     weapons.on=FALSE;
     weapons.inum=0;
     weapons.oldinum=0;
     weapons.x=SCREENWIDTH/3;
     weapons.y=SCREENHEIGHT-146;$IV,1$$IV,0$
    
     weapons.data=0;
    
     weapons.p[0]=PUNCH;
     weapons.p[1]=PUNCH1;
     weapons.p[2]=PUNCH2;
     weapons.p[3]=PUNCH3;

     weapons.p[4]=PISTOL;
     weapons.p[5]=PISTOL1;
     weapons.p[6]=PISTOL2;
     weapons.p[7]=PISTOL3;
     weapons.p[8]=PISTOLU;
     weapons.p[9]=PISTOLF;

     weapons.p[10]=SHOTGUN;
     weapons.p[11]=SHOTGUN1;
     weapons.p[12]=SHOTGUN2;
     weapons.p[13]=SHOTGUN3;
     weapons.p[14]=SHOTGUNF1;
     weapons.p[15]=SHOTGUNF2;
     
     weapons.p[16]=CHAINGUN;
     weapons.p[17]=CHAINGUN1;
     weapons.p[18]=CHAINGUNF1;
     weapons.p[19]=CHAINGUNF2;
     
     weapons.p[20]=MISSILELAUNCHER;
     weapons.p[21]=MISSILELAUNCHER1;
     weapons.p[22]=MISSILELAUNCHERF1;
     weapons.p[23]=MISSILELAUNCHERF2;
     weapons.p[24]=MISSILELAUNCHERF3;
     weapons.p[25]=MISSILELAUNCHERF4;
     
     weapons.p[26]=CHAINSAW;
     weapons.p[27]=CHAINSAW1;
     weapons.p[28]=CHAINSAW2;
     weapons.p[29]=CHAINSAW3; 

     weapons.p[30]=PLASMAGUN;
     weapons.p[31]=PLASMAGUN1;
     weapons.p[32]=PLASMAGUNF1;
     weapons.p[33]=PLASMAGUNF2;     
    
     weapons.p[34]=BFG;
     weapons.p[35]=BFG1;
     weapons.p[36]=BFG2;
     weapons.p[37]=BFGF1;     
     weapons.p[38]=BFGF2;     
    
     
   }

  
  
}

U0 AnimateFire(I16 weapon)
{
   if(weapons.on)
   {
    switch(weapon)
    {
     case 0://punch
        switch(weapons.oldinum)
        {
          case -1:
           weapons.oldinum=0;
           weapons.inum=1;
           break;
	  case 0:
           weapons.oldinum=1;
           weapons.inum=2;
           break;
	  case 1:
           weapons.oldinum=2;
           weapons.inum=3;
           break;
	  case 2:
           weapons.oldinum=3;
           weapons.inum=2;
           break;
	  case 3:
           weapons.oldinum=4;
           weapons.inum=1;
           break;
	  case 4:
           weapons.oldinum=5;
           weapons.inum=0;
           break;
	  case 5:
           weapons.oldinum=0;
           weapons.inum=0;
           weapons.on=FALSE;
           break;

        }
     break;
     case 1://pistol
       switch(weapons.oldinum)
        {
          case -1:
           weapons.oldinum=0;
           weapons.inum=4;
           break;
	  case 0:
           weapons.x=SCREENWIDTH/3;
           weapons.oldinum=1;
           weapons.inum=5;
           break;
	  case 1:
           weapons.oldinum=2;
           weapons.inum=7;
           break;
	  case 2:
           
           weapons.oldinum=3;
           //weapons.x=SCREENWIDTH/2;
           //weapons.y=SCREENHEIGHT/2;
           weapons.inum=8;
           break;
	  case 3:
           weapons.oldinum=4;
           weapons.data=9;
           Play("tttB#...");
           weapons.inum=8;
           break;
	  case 4:
           weapons.data=0;
           weapons.oldinum=5;
           weapons.inum=8;
           break;
	  case 5:
           weapons.oldinum=6;
           weapons.inum=7;
           break;
	  case 6:
           weapons.oldinum=7;
           weapons.inum=6;
           break;
          case 7:
           weapons.oldinum=8;
           weapons.inum=5;
           break; 
	  case 8:
           weapons.x=SCREENWIDTH/2.5;
           weapons.oldinum=0;
           weapons.inum=4;
           weapons.on=FALSE;
           break;

        }
 
     break;
     case 2://shotgun
       switch(weapons.oldinum)
        {
          case -1:
           //weapons.data=14;
           //weapons.x=SCREENWIDTH/2.16;
           weapons.y=SCREENHEIGHT-164;
           weapons.oldinum=0;
           weapons.inum=10;
           break;
	  case 0:
           weapons.data=15;
           weapons.oldinum=1;
           weapons.inum=10;
           Play("tttA#...");
           break;
	  case 1:
           weapons.data=14;
           weapons.oldinum=2;
           weapons.inum=10;
           //Play("1A");
           break;
	  case 2:            
           weapons.data=0;
           weapons.oldinum=3;
           weapons.inum=10;
           break;
	  case 3:
           weapons.oldinum=4;
           weapons.inum=11;
           weapons.x=SCREENWIDTH/4.5;
           weapons.y=SCREENHEIGHT-306;
           Sleep(40);
           break;
	  case 4:
           weapons.oldinum=5;
           weapons.inum=12;
           Play("tttG#...");
	   Sleep(40);
           break;
 	  case 5:
           weapons.oldinum=6; 
           weapons.inum=13;
           Play("tttG...");
           Sleep(40);
           break;
	  case 6:
           weapons.oldinum=7;
           weapons.inum=12;
	   Sleep(40);
           break;
	  case 7:
           weapons.x=SCREENWIDTH/2.5;
           weapons.y=SCREENHEIGHT-184;
           weapons.oldinum=8;
	   weapons.inum=11;
           Sleep(40);
           break;	 
	  case 8:
           weapons.oldinum=0;
           weapons.inum=10;
           weapons.on=FALSE;
           break;

        }
     break;
     case 3://chaingun
       switch(weapons.oldinum)
        {
          case -1:
            //weapons.x=
            weapons.oldinum=0;
            weapons.data=19;
            weapons.inum=17;
            Play("tttC#...");
            Sleep(5);
            break;
          case 0:
            weapons.oldinum=0;
            weapons.data=18;
            weapons.inum=16;
            Play("tttC...");
            //Sleep(5);
            weapons.on=FALSE;
            break;
        }
     break;
     case 4://missile launcher
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=21;
            weapons.data=22;
            weapons.y=weapons.y+25;
            Sleep(5);
            Play("tttF#...");
            break;
          case 0:
            weapons.oldinum=1;
            weapons.data=23;
            Sleep(5);
            Play("tttF...");
            break;
          case 1:
            weapons.oldinum=2;
            weapons.data=24;
            weapons.y=weapons.y-15;
            Sleep(5);
            Play("tttE#...");
            break;
          case 2:
            weapons.oldinum=3;
            weapons.data=25;
            weapons.y=weapons.y-5;
            Sleep(5);
            Play("tttE...");
            break;
          case 3:
            weapons.oldinum=0;
            weapons.data=0;
            weapons.y=weapons.y-5;
            weapons.inum=20;
            Sleep(5);
            Play("tttD#...");
            weapons.on=FALSE;
            break;
             
        }
     break;
     case 5://chainsaw
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=27;
            Play("tttA...");
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=28;
            weapons.y=weapons.y-86;
            Play("tttA#...");
            break;
          case 1:
            weapons.oldinum=2;
            weapons.inum=29;
            Play("tttA#...");
            break;
          case 2:
            weapons.oldinum=3;
            weapons.inum=28;
            Play("tttA#...");
            break;
          case 3:
            weapons.oldinum=0;
            weapons.y=weapons.y+86;
            weapons.inum=27;
            Play("tttA#...");
            weapons.on=FALSE;
            break;
        }
     break;
     case 6://plasma gun
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=32;
            //weapons.data=32;
            Sleep(20);
            Play("tttG...");
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=33;
             Sleep(20);
            //weapons.data=33;
            Play("tttG#...");
            break;
          case 1:
            weapons.oldinum=2;
            weapons.x=weapons.x-86;
            weapons.y=weapons.y-92;
            weapons.inum=31;
            Sleep(240);
            //weapons.data=33;
            //Play("tttG#...");
            break;
          case 2:
            weapons.oldinum=0;
            weapons.inum=30;
            weapons.data=0;
            weapons.x=weapons.x+86;
            weapons.y=weapons.y+92;
            weapons.on=FALSE;
            break;
        }
     break;
     case 7://BFG
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=35;
            //weapons.data=32;
            Sleep(20);
            Play("tttB...");
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=36;
            weapons.data=37;
            Sleep(20);
            //weapons.data=33;
            Play("tttF...");
            break;
          case 1:
            weapons.oldinum=2;
            //weapons.x=weapons.x-86;
            //weapons.y=weapons.y-92;
            weapons.data=38;
            Sleep(60);
            //weapons.data=33;
            Play("tttG...");
            break;
          case 2:
            weapons.oldinum=0;
            weapons.inum=35;
            weapons.data=0;
            //weapons.x=weapons.x+86;
            //weapons.y=weapons.y+92;
            weapons.on=FALSE;
            break;
        }
     break;

    }
   }
}

U0 SwapWeapon(I64 weapon)
{
  switch(weapon)
  {
   case 0:
    weapons.x=SCREENWIDTH/3;
    weapons.y=SCREENHEIGHT-146;
    weapons.inum=0;//hands
    weapons.data=0;
    weapons.on=FALSE;
    break;
   case 1:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.5;
    weapons.y=SCREENHEIGHT-186;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=8;//pistol
    Sleep(20);
    weapons.inum=5;
    Sleep(20);   
    weapons.inum=4;
    Sleep(20);
    weapons.on=FALSE;
    break;
   case 2:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.5;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=12;//shotgun
    Sleep(20);
    weapons.inum=11;//shotgun
    Sleep(20);    
    weapons.inum=10;//shotgun
    Sleep(20);
    weapons.on=FALSE;
    
    break;
   case 3:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/3;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$//chaingun
    weapons.data=0;
    weapons.inum=17;
    Sleep(20);
    weapons.inum=16;
    Sleep(20);
    weapons.on=FALSE;
    
    break;
   case 4:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.75;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=21;//missile launcher
    Sleep(20);
    weapons.inum=20;
    Sleep(20);    
    weapons.on=FALSE;
    
    break;
   case 5:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/3.5;
    weapons.y=SCREENHEIGHT-146;$IV,1$$IV,0$
    weapons.data=0;
    //weapons.inum=29;//chainsaw
    //Sleep(20);
    //weapons.inum=28;
    //Sleep(20);
    //weapons.inum=27;
    //Sleep(20);        
    weapons.inum=26;
    Sleep(20);
    weapons.on=FALSE;
    
    break;
   case 6:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.75;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=31;//plasma gun
    Sleep(20);
    weapons.inum=30;
    Sleep(20);    
    weapons.on=FALSE;
    
    break;
   case 7:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/4;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=36;//BFG
    Sleep(20);
    weapons.inum=35;
    Sleep(20);    
    weapons.inum=34;
    Sleep(20);
    weapons.on=FALSE;
    
    break;
   
   break;
  }
}

U0 ST_Fire()
{
   if(weapons.on==FALSE)
   {
     weapons.on=TRUE;
     weapons.oldinum=-1;
     
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

U0 ST_Start(CDC*dc, CDoomPlayer p)
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
  Free(weapons.p);
}

//ST_Start;
