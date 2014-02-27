*** ../ari1.00/skksrch.c	Sat Apr 11 06:42:03 1992
--- skksrch.c	Tue May 12 09:52:53 1992
***************
*** 27,33 ****
   * disctionary. He also implemented this function as 'IDX_SAVE' option to keep
   * their binary image in files which were isolated from the SKK dictionaries.
   */
! static char *version = "skksrch version 1.00,  04.12.1992\n";
  
  #include "config.h"
  #include <sys/types.h>
--- 27,33 ----
   * disctionary. He also implemented this function as 'IDX_SAVE' option to keep
   * their binary image in files which were isolated from the SKK dictionaries.
   */
! static char *version = "skksrch version 1.00a,  05.11.1992";
  
  #include "config.h"
  #include <sys/types.h>
***************
*** 39,44 ****
--- 39,45 ----
  #else
  # include <string.h>
  #endif
+ #include <time.h>
  #include <stdio.h>
  #include <errno.h>
  
***************
*** 124,129 ****
--- 125,131 ----
                          /* pos[KANA_SIZE]   KANA_MAX            */
                          /* pos[KANA_SIZE+1] more than KANA_MAX  */
                          /* pos[KANA_SIZE+2] terminator          */
+     long rpos[POS_SIZE]; /* pos for entries with okurigana */
      long base;  /* point of first entry */
  } l_tbl, g_tbl;
  
***************
*** 135,141 ****
       *gdic_name = NULL,
       *src_dic   = NULL,
       *start_index_mark = " Start of Index\n",
!      *end_index_mark   = " End of Index\n";
  
  static int curpos, debug;
  
--- 137,146 ----
       *gdic_name = NULL,
       *src_dic   = NULL,
       *start_index_mark = " Start of Index\n",
!      *end_index_mark   = " End of Index\n",
!      *okuri_ari  = " okuri-ari entries.",
!      *okuri_nasi = " okuri-nasi entries.",
!      *add_index_msg = ";; Index is added by ";
  
  static int curpos, debug;
  
***************
*** 319,333 ****
      int i;
      long l;
  
      for ( i = l = 0 ; i < POS_SIZE ; i++) {
!         fprintf(fp, " %09ld", l_tbl.pos[i]);
!         l += 10;
!         if (l >= 70) {
!             fputc('\n', fp);
              l = 0;
          }
      }
!     fputc('\n', fp);
  }
  
  static int
--- 324,339 ----
      int i;
      long l;
  
+     fputs(";;", fp);
      for ( i = l = 0 ; i < POS_SIZE ; i++) {
!         fprintf(fp, " %09ld:%09ld", l_tbl.pos[i], l_tbl.rpos[i]);
!         l += 20;
!         if (l >= 60) {
!             fputs("\n;;", fp);
              l = 0;
          }
      }
!     fputs("\n", fp);
  }
  
  static int
***************
*** 337,342 ****
--- 343,350 ----
  {
      int i, l;
      FILE *fp;
+     time_t clk;
+     char *p;
  
      if ((l_tbl.fp = fopen(s, DIC_RDMODE)) == NULL) {
          fprintf(stderr, "%s : can not open jisyo to read\n", s);
***************
*** 359,367 ****
      init_tbl(&l_tbl);
  
      /* write index */
!     fputs(start_index_mark, fp);
      wr_postbl(fp);
!     fputs(end_index_mark, fp);
  
      /* copy body */
      fseek(l_tbl.fp, l_tbl.base, 0);
--- 367,377 ----
      init_tbl(&l_tbl);
  
      /* write index */
!     time(&clk); p = ctime(&clk); p[10] = 0;
!     fprintf(fp, "%s`%s' at %s %s", add_index_msg, version, &p[4], &p[20]);
!     fprintf(fp, ";;%s", start_index_mark);
      wr_postbl(fp);
!     fprintf(fp, ";;%s", end_index_mark);
  
      /* copy body */
      fseek(l_tbl.fp, l_tbl.base, 0);
***************
*** 407,413 ****
  init_tbl(p)
      struct jdic_tbl *p;
  {
!     int idx, cur_idx, c1, c2;
      long cur_pos;
      FILE *fp;
  
--- 417,423 ----
  init_tbl(p)
      struct jdic_tbl *p;
  {
!     int idx, cur_idx, c1, c2, slen;
      long cur_pos;
      FILE *fp;
  
***************
*** 424,456 ****
      fseek(fp, 0L, 0);
      idx = 0;
      p->pos[idx] = 0L;
      while ((c1 = fgetc(fp)) == ' ') {
          skip_entry(fp);
      }
!     if (c1 == EOF) {
!         fseek(fp, 0L, 2);
!         p->base = ftell(fp);
!         while (idx < KANA_SIZE + 2) {
!             p->pos[++idx] = 0L;
!         }
!         return;
!     }
      p->base = cur_pos = ftell(fp) - 1L;
      fseek(fp, cur_pos, 0);
      while(idx < KANA_SIZE) {
          if ((c1 = fgetc(fp)) == EOF) break;
          if ((c2 = fgetc(fp)) == EOF) break;
!         cur_idx = codetoidx(calcode(c1, c2));
!         cur_pos = ftell(fp);
!         while(idx < cur_idx) {
!             p->pos[++idx] = cur_pos - 2L - p->base;
          }
!         skip_entry(fp);
      }
      fseek(fp, 0L, 2);
      cur_pos = ftell(fp) - p->base;
      while (idx < KANA_SIZE + 2) {
!         p->pos[++idx] = cur_pos ;
      }
      return;
  }
--- 434,529 ----
      fseek(fp, 0L, 0);
      idx = 0;
      p->pos[idx] = 0L;
+     p->rpos[idx] = 0L;
      while ((c1 = fgetc(fp)) == ' ') {
          skip_entry(fp);
      }
!     if (c1 == EOF)
!         goto no_entry;
! 
      p->base = cur_pos = ftell(fp) - 1L;
      fseek(fp, cur_pos, 0);
+     /*
+      * skip comment
+      */
+     Debug((stderr, "skip comment\n"));
+     slen=strlen(okuri_ari);
+     while (fgets(entrybuf, ENTRYBUF - 1, fp) != NULL) {
+         if (entrybuf[0] == ';' && entrybuf[1] == ';') {
+             if (strncmp(entrybuf+2, okuri_ari, slen) == 0)
+                 goto for_rpos;
+             if (strcmp(entrybuf+2, end_index_mark) == 0)
+                 p->base = ftell(fp);
+         }
+         else {
+             fseek(fp, cur_pos, 0);
+             idx = 0;
+             while (idx < POS_SIZE)
+                 p->rpos[idx++] = cur_pos;
+             goto for_pos;
+         }
+        cur_pos = ftell(fp);
+     }
+     goto no_entry;
+ 
+ for_rpos:
+     Debug((stderr, "make rpos table\n"));
+     idx = cur_idx = KANA_SIZE + 2;
+     cur_pos = ftell(fp);
+     p->rpos[idx] = cur_pos - p->base;
+     slen = strlen(okuri_nasi);
+     while (idx > 0) {
+         if ((c1 = fgetc(fp)) == EOF) break;
+         if ((c2 = fgetc(fp)) == EOF) break;
+         if (c1 == ';' && c2 == ';') {
+             cur_pos = ftell(fp) - 2L;
+             if (fgets(entrybuf, ENTRYBUF - 1, fp) == NULL) break;
+             if (strncmp(entrybuf, okuri_nasi, slen) == 0) break;
+         }
+         else {
+             cur_idx = codetoidx(calcode(c1, c2));
+             cur_pos = ftell(fp);
+             while(idx > cur_idx) {
+                 p->rpos[--idx] = cur_pos - 2L - p->base;
+             }
+             skip_entry(fp);
+         }
+     }
+     while (idx > 0) {
+         p->rpos[--idx] = cur_pos - p->base;
+     }
+ 
+ for_pos:
+     Debug((stderr, "make pos table\n"));
+     idx = 0;
      while(idx < KANA_SIZE) {
          if ((c1 = fgetc(fp)) == EOF) break;
          if ((c2 = fgetc(fp)) == EOF) break;
!         if (c1 == ';' && c2 == ';') {
!             if (fgets(entrybuf, ENTRYBUF - 1, fp) == NULL) break;
          }
!         else {
!             cur_idx = codetoidx(calcode(c1, c2));
!             cur_pos = ftell(fp);
!             while(idx < cur_idx) {
!                 p->pos[++idx] = cur_pos - 2L - p->base;
!             }
!             skip_entry(fp);
!         }
      }
      fseek(fp, 0L, 2);
      cur_pos = ftell(fp) - p->base;
      while (idx < KANA_SIZE + 2) {
!         p->pos[++idx] = cur_pos;
!     }
!     return;
! 
! no_entry:
!     fseek(fp, 0L, 2);
!     p->base = ftell(fp);
!     while (idx < KANA_SIZE + 2) {
!         p->pos[++idx] = 0L;
!         p->rpos[idx] = 0L;
      }
      return;
  }
***************
*** 463,485 ****
      struct jdic_tbl *tblp;
  {
      FILE *fp;
!     int idx, c;
!     long l;
      char *p;
  
      fp = tblp->fp;
      if (fgets(entrybuf, ENTRYBUF - 1, fp) == NULL)
          return 0;
!     if (strcmp(entrybuf, start_index_mark) != 0)
          return 0;
  
      /* read index */
!     l = 0;
      idx = 0;
      while (fgets(entrybuf, ENTRYBUF - 1, fp) != NULL) {
!         if (entrybuf[0] != ' ')
              return 0; /* wrong index */
!         if (strcmp(entrybuf, end_index_mark) == 0)
              break;
          p = entrybuf;
          while (idx < POS_SIZE) {
--- 536,562 ----
      struct jdic_tbl *tblp;
  {
      FILE *fp;
!     int idx, c, pad;
!     long l, rl;
      char *p;
  
      fp = tblp->fp;
      if (fgets(entrybuf, ENTRYBUF - 1, fp) == NULL)
          return 0;
!     if (strncmp(entrybuf, add_index_msg, strlen(add_index_msg)) == 0 &&
!         fgets(entrybuf, ENTRYBUF - 1, fp) == NULL)
!         return 0;
!     pad = (entrybuf[0] == ';' && entrybuf[1] == ';') ? 2: 0;
!     if (strcmp(entrybuf + pad, start_index_mark) != 0)
          return 0;
  
      /* read index */
!     l = rl = 0L;
      idx = 0;
      while (fgets(entrybuf, ENTRYBUF - 1, fp) != NULL) {
!         if (entrybuf[pad] != ' ')
              return 0; /* wrong index */
!         if (strcmp(entrybuf + pad, end_index_mark) == 0)
              break;
          p = entrybuf;
          while (idx < POS_SIZE) {
***************
*** 487,497 ****
              if (c == 0)
                  break;
              for (l = 0; '0' <= (c = *p++) && c <= '9'; l = l*10 + c-'0') ;
!             tblp->pos[idx++] = l;
          }
      }
!     while (idx < POS_SIZE)
          tblp->pos[idx++] = l;
  
      /* skip wrong entry */
      while ((c = fgetc(fp)) == ' ') {
--- 564,585 ----
              if (c == 0)
                  break;
              for (l = 0; '0' <= (c = *p++) && c <= '9'; l = l*10 + c-'0') ;
!             tblp->pos[idx] = l;
!             if (c == ':') {
!                 p++;
!                 for (rl=0; '0' <= (c = *p++) && c <= '9'; rl = rl*10 + c-'0') ;
!                 tblp->rpos[idx] = rl;
!             }
!             else {
!                 tblp->rpos[idx] = 0L;
!             }
!             idx++;
          }
      }
!     while (idx < POS_SIZE) {
!         tblp->rpos[idx] = rl;
          tblp->pos[idx++] = l;
+     }
  
      /* skip wrong entry */
      while ((c = fgetc(fp)) == ' ') {
***************
*** 505,510 ****
--- 593,600 ----
      for (idx = 1 ; idx < POS_SIZE; idx++) {
          if (tblp->pos[idx-1] > tblp->pos[idx])
              return 0; /* wrong index */
+         if (tblp->rpos[idx-1] < tblp->rpos[idx])
+             return 0; /* wrong index */
      }
      /* check file size */
      fseek(fp, 0L, 2);
***************
*** 527,535 ****
  
      if (p->fp == NULL) return 0;
  
!     i = codetoidx(calcode(s[0], s[1]));
!     start = p->pos[i] + p->base;
!     end = p->pos[i + 1] + p->base;
      fseek(p->fp, start, 0);
      while(start < end) {
          for (i = 0; (c=(s[i]&0xff)) >= ' ' && c == (fgetc(p->fp)&0xff); i++) {
--- 617,640 ----
  
      if (p->fp == NULL) return 0;
  
!     for (i = 0; (c=(s[i]&0xff)) > ' '; i++) ;
!     if (i >= 3 && 'a' <= (c=(s[i-1]&0xff)) && c <= 'z' && (s[0]&0xff) >= 0x80) {
!         /* okuri-ari */
!         Debug((stderr, "find_key: okuri-ari\n"));
!         i = codetoidx(calcode(s[0], s[1])); /* i must be greater than 0 */
!         start = p->rpos[i] + p->base;
!         end = p->rpos[i - 1] + p->base;
!         if (start == end) {
!             start = p->pos[i] + p->base;
!             end = p->pos[i + 1] + p->base;
!         }
!     }
!     else {
!         Debug((stderr, "find_key: okuri-nasi\n"));
!         i = codetoidx(calcode(s[0], s[1]));
!         start = p->pos[i] + p->base;
!         end = p->pos[i + 1] + p->base;
!     }
      fseek(p->fp, start, 0);
      while(start < end) {
          for (i = 0; (c=(s[i]&0xff)) >= ' ' && c == (fgetc(p->fp)&0xff); i++) {
***************
*** 1068,1073 ****
--- 1173,1179 ----
          case 'V':
              fputs("1", stdout);
              fputs(version, stdout);
+             fputs("\n", stdout);
              fflush(stdout);
              break;
  #ifdef UPDATE_DIC
