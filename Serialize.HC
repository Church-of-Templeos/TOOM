

U0 DumpClass(U8 *ptr, U8 *lc=lastclass)
{
 CHashClass *cls=HashFind(lc,Fs->hash_table,HTT_CLASS);
 CMemberLst *mlst;

 if(!cls) return;
 while(cls)
 {
  for(mlst=cls->member_lst_and_root;mlst;mlst=mlst->next)
  {
   switch(mlst->member_class->raw_type)
   {
    case RT_U0...RT_U64:
    break;
    //case RT_I0...RT_I64:
    //break;
    case RT_F64:
    break;
   }
  }
  cls=cls->base_class;
 }
 
}

U0 SaveGame()
{

}