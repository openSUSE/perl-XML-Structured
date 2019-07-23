#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <dlfcn.h>


static void
addescaped(SV *dstsv, SV *srcsv)
{
  unsigned char *src, *srcp;
  STRLEN i, srcl, bigcnt = 0, ctrlcnt = 0, badcnt = 0, xcnt = 0;
  int c, uniok;
  int state;

  src = (unsigned char *)SvPV(srcsv, srcl);
  if (!src)
    return;
  uniok = 1;
  state = 0;
  for (i = 0, srcp = src; i < srcl; i++)
    {
      c = *srcp++;
      if (c < 32 && c != 9 && c != 10 && c != 13)
	{
	  ctrlcnt++;
	  if (!state)
	    {
	      badcnt++;
	      continue;
	    }
	}
      else if (c >= 128)
	bigcnt++;
      else
	{
	  if (c == '&')
	    xcnt += 4;
	  else if (c == '<')
	    xcnt += 3;
	  else if (c == '>')
	    xcnt += 3;
	  else if (c == '"')
	    xcnt += 5;
	  if (!state)
	    continue;	/* common case */
	}
      if (!uniok)
	continue;
      if (state)
	{
	  if ((c & 0xc0) != 0x80)
	    {
	      /* encoding error */
	      uniok = 0;
	      continue;
	    }
	  c = (c & 0x3f) | (state << 6);
	  if (!(state & 0x40000000))
	    {
	      /* check for overlong sequences */
	      if ((c & 0x820823e0) == 0x80000000)
		c = 0xfdffffff;
	      else if ((c & 0x020821f0) == 0x02000000)
		c = 0xfff7ffff;
	      else if ((c & 0x000820f8) == 0x00080000)
		c = 0xffffd000;
	      else if ((c & 0x0000207c) == 0x00002000)
		c = 0xffffff70;
	    }
	}
      else
	{
	  /* new sequence */
	  if (c >= 0xfe)
	    {
	      uniok = 0;
	      continue;
	    }
	  else if (c >= 0xfc)
	    c = (c & 0x01) | 0xbffffffc;    /* 5 bytes to follow */
	  else if (c >= 0xf8)
	    c = (c & 0x03) | 0xbfffff00;    /* 4 */
	  else if (c >= 0xf0)
	    c = (c & 0x07) | 0xbfffc000;    /* 3 */
	  else if (c >= 0xe0)
	    c = (c & 0x0f) | 0xbff00000;    /* 2 */
	  else if (c >= 0xc2)
	    c = (c & 0x1f) | 0xfc000000;    /* 1 */
	  else if (c >= 0x80)
	    {
	      uniok = 0;
	      continue;
	    }
	}
      state = (c & 0x80000000) ? c : 0;
      if (state)
	continue;
      if (c < 32 && c != 9 && c != 10 && c != 13)
	badcnt++;
      else if (c == 0xfffe || c == 0xffff)
	badcnt++;
      else if (c >= 0xd800 && c < 0xe000)
	badcnt++;
      else if (c >= 0x110000)
	badcnt++;
    }
  if (uniok && state)
    badcnt++;		/* unterminated sequence */
  if (!uniok)
    {
      STRLEN dlen;
      unsigned char *dp;
      /* transcode from ISO-8859-1 to unicode */
      STRLEN new = srcl + bigcnt - ctrlcnt + xcnt;
      dlen = SvCUR(dstsv);
      SvGROW(dstsv, dlen + new + 1);
      dp = (unsigned char *)SvPVX(dstsv) + dlen;
      for (i = 0, srcp = src; i < srcl; i++)
	{
	  c = *srcp++;
	  if (c < 32 && c != 9 && c != 10 && c != 13)
	    continue;	/* too bad, can't encode */
	  else if (c < 0x80)
	    {
	      if (c == '&')
		{
		  strcpy((char *)dp, "&amp;");
		  dp += 5;
		}
	      else if (c == '<')
		{
		  strcpy((char *)dp, "&lt;");
		  dp += 4;
		}
	      else if (c == '>')
		{
		  strcpy((char *)dp, "&gt;");
		  dp += 4;
		}
	      else if (c == '"')
		{
		  strcpy((char *)dp, "&quot;");
		  dp += 6;
		}
	      else
	        *dp++ = c;
	    }
	  else
	    {
	      *dp++ = 0xc0 | (c >> 6);
	      *dp++ = 0x80 | (c & 0x3f);
	    }
	}
      *dp = 0;
      SvCUR_set(dstsv, dlen + new);
    }
  else if (!badcnt)
    {
      /* good unicode, nice! */
      STRLEN dlen;
      unsigned char *dp;
      dlen = SvCUR(dstsv);
      SvGROW(dstsv, dlen + srcl + xcnt + 1);
      dp = (unsigned char *)SvPVX(dstsv) + dlen;
      if (srcl)
	{
	  if (!xcnt)
	    {
	      if (srcl)
                memcpy(dp, src, srcl);
	      dp += srcl;
	    }
	  else
	    {
	      for (i = 0, srcp = src; i < srcl; i++)
		{
		  c = *srcp++;
		  if (c == '&')
		    {
		      strcpy((char *)dp, "&amp;");
		      dp += 5;
		    }
		  else if (c == '<')
		    {
		      strcpy((char *)dp, "&lt;");
		      dp += 4;
		    }
		  else if (c == '>')
		    {
		      strcpy((char *)dp, "&gt;");
		      dp += 4;
		    }
		  else if (c == '"')
		    {
		      strcpy((char *)dp, "&quot;");
		      dp += 6;
		    }
		  else
		    *dp++ = c;
		}
	    }
	}
      *dp = 0;
      SvCUR_set(dstsv, dlen + xcnt + srcl);
    }
  else
    {
      /* good unicode, bad non-xml chars. hard work... */
      STRLEN dlen;
      unsigned char *dp, *dpstart;
      dlen = SvCUR(dstsv);
      SvGROW(dstsv, dlen + srcl + xcnt + 1);
      dpstart = (unsigned char *)SvPVX(dstsv);
      dp = dpstart + dlen;
      state = 0;
      for (i = 0, srcp = src; i < srcl; i++)
	{
	  c = *srcp++;
	  if (state)
	    {
	      c = (c & 0x3f) | (state << 6);
	      if (!(state & 0x40000000))
		{
		  /* check for overlong sequences */
		  if ((c & 0x820823e0) == 0x80000000)
		    c = 0xfdffffff;
		  else if ((c & 0x020821f0) == 0x02000000)
		    c = 0xfff7ffff;
		  else if ((c & 0x000820f8) == 0x00080000)
		    c = 0xffffd000;
		  else if ((c & 0x0000207c) == 0x00002000)
		    c = 0xffffff70;
		}
	    }
	  else
	    {
	      if (c < 0x80)
		{
		  /* optimize a bit */
		  if (c < 0x20 && (c != 9 && c != 10 && c != 13))
		    continue;
		  if (c == '&')
		    {
		      strcpy((char *)dp, "&amp;");
		      dp += 5;
		    }
		  else if (c == '<')
		    {
		      strcpy((char *)dp, "&lt;");
		      dp += 4;
		    }
		  else if (c == '>')
		    {
		      strcpy((char *)dp, "&gt;");
		      dp += 4;
		    }
		  else if (c == '"')
		    {
		      strcpy((char *)dp, "&quot;");
		      dp += 6;
		    }
		  else
		    *dp++ = c;
		  continue;
		}
	      if (c >= 0xfc)
		c = (c & 0x01) | 0xbffffffc;    /* 5 bytes to follow */
	      else if (c >= 0xf8)
		c = (c & 0x03) | 0xbfffff00;    /* 4 */
	      else if (c >= 0xf0)
		c = (c & 0x07) | 0xbfffc000;    /* 3 */
	      else if (c >= 0xe0)
		c = (c & 0x0f) | 0xbff00000;    /* 2 */
	      else
		c = (c & 0x1f) | 0xfc000000;    /* 1 */
	    }
	  state = (c & 0x80000000) ? c : 0;
	  if (state)
	    continue;
	  if (c < 32 && c != 9 && c != 10 && c != 13)
	    continue;
	  else if (c == 0xfffe || c == 0xffff)
	    continue;
	  else if (c >= 0xd800 && c < 0xe000)
	    continue;
	  else if (c >= 0x110000)
	    continue;
	  /* now encode */
	  if (c < 0x80)
	    {
	      if (c == '&')
		{
		  strcpy((char *)dp, "&amp;");
		  dp += 5;
		}
	      else if (c == '<')
		{
		  strcpy((char *)dp, "&lt;");
		  dp += 4;
		}
	      else if (c == '>')
		{
		  strcpy((char *)dp, "&gt;");
		  dp += 4;
		}
	      else if (c == '"')
		{
		  strcpy((char *)dp, "&quot;");
		  dp += 6;
		}
	      else
	        *dp++ = c;
	    }
	  else if (c < 0x800)
	    {
	      *dp++ = 0xc0 | c >> 6;
	      *dp++ = 0x80 | (c & 0x3f);
	    }
	  else if (c < 0x10000)
	    {
	      *dp++ = 0xe0 | c >> 12;
	      *dp++ = 0x80 | (c >> 6 & 0x3f);
	      *dp++ = 0x80 | (c & 0x3f);
	    }
	  else
	    {
	      *dp++ = 0xf0 | c >> 18;
	      *dp++ = 0x80 | (c >> 12 & 0x3f);
	      *dp++ = 0x80 | (c >> 6 & 0x3f);
	      *dp++ = 0x80 | (c & 0x3f);
	    }
	}
      *dp = 0;
      SvCUR_set(dstsv, dp - dpstart);
    }
}

static void
addsimple(SV *dstsv, SV *srcsv)
{
  STRLEN dlen, srcl;
  unsigned char *src, *dp;

  src = (unsigned char *)SvPV(srcsv, srcl);
  dlen = SvCUR(dstsv);
  SvGROW(dstsv, dlen + srcl + 1);
  dp = (unsigned char *)SvPVX(dstsv) + dlen;
  if (srcl)
    memcpy(dp, src, srcl);
  dp[srcl] = 0;
  SvCUR_set(dstsv, dlen + srcl);
}

static int handlechar_bytes;

MODULE = XML::Structured PACKAGE = XML::Structured

PROTOTYPES: ENABLE

void
_setbytes(int bytes)
CODE:
    handlechar_bytes = bytes;

void
_addescaped(SV *dstsv, SV *srcsv)
CODE:
  if (!SvPOKp(dstsv)) {
    croak("addescaped: target is not a string\n");
    XSRETURN_UNDEF;
  }
  if (SvOK(srcsv)) {
    if (!(SvPOK(srcsv) || SvNOK(srcsv) || SvIOK(srcsv))) {
      croak("addescaped: source is not a string\n");
      XSRETURN_UNDEF;
    }
    addescaped(dstsv, srcsv);
  }


void
_addescaped3(SV *dstsv, SV *srcsv1, SV *srcsv2, SV *srcsv3)
CODE:
  if (!SvPOKp(dstsv)) {
    croak("addescaped3: target is not a string\n");
    XSRETURN_UNDEF;
  }
  if (!SvPOKp(srcsv1)) {
    croak("addescaped3: source1 is not a string\n");
    XSRETURN_UNDEF;
  }
  addsimple(dstsv, srcsv1);
  if (SvOK(srcsv2)) {
    if (!(SvPOK(srcsv2) || SvNOK(srcsv2) || SvIOK(srcsv2))) {
      croak("addescaped3: source2 is not a string\n");
      XSRETURN_UNDEF;
    }
    addescaped(dstsv, srcsv2);
  }
  if (!SvPOKp(srcsv3)) {
    croak("addescaped3: source3 is not a string\n");
    XSRETURN_UNDEF;
  }
  addsimple(dstsv, srcsv3);





void
_handle_char(HV *phv, SV *strsv)
CODE:
  SV *sv, **svp;
  /* can also call with a sax2 hash containing a 'Data' element */
  if (SvROK(strsv) && SvTYPE(SvRV(strsv)) == SVt_PVHV) {
    SV **datap = hv_fetch((HV *)SvRV(strsv), "Data", 4, 0);
    if (datap && *datap)
      strsv = *datap;
  }
  if (!SvPOKp(strsv)) {
    croak("_handle_char: not a string\n");
    XSRETURN_UNDEF;
  }
  svp = hv_fetch(phv, "work", 4, 0);
  sv = svp ? *svp : 0;
  if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)
    {
      AV *av = (AV *)SvRV(sv);
      I32 depth = av_len(av);
      if (depth >= 0)
	{
	  svp = av_fetch(av, depth, 0);
	  sv = svp ? *svp : 0;
	  if (sv && SvOK(sv))
	    {
	      if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PV)
		sv = (SV *)SvRV(sv);
	      if (handlechar_bytes)
	        SvUTF8_off(strsv);
	      sv_catsv(sv, strsv);
	    }
	  else
	    {
	      STRLEN strl;
	      char *sp = SvPV(strsv, strl);
	      for (; strl-- > 0; sp++)
		{
		  if (*sp != ' ' && *sp != '\t' && *sp != '\r' && *sp != '\n')
		    {
		      char *elementname = 0;
		      svp = av_fetch(av, depth - 2, 0);
		      sv = svp ? *svp : 0;
		      if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)
			{
			  HV *hv = (HV *)SvRV(sv);
			  svp = hv_fetch(hv, ".", 1, 0);
			  sv = svp ? *svp : 0;
			  if (sv)
			    elementname = SvPV_nolen(sv);
			}
		      croak("element '%s' contains content\n", elementname ? elementname : "???");
		      XSRETURN_UNDEF;
		    }
		}
	    }
	}
    }

void
_handle_start(HV *phv, SV *enamesv, ...)
CODE:
  SV *sv, **svp, *chrsv, *ksv;
  AV *workav;
  HV *knownhv, *outhv;
  I32 depth;
  I32 enamelen;
  char *ename;
  HV *attributes = 0;
  U32 itemcnt;

  if (SvROK(enamesv) && SvTYPE(SvRV(enamesv)) == SVt_PVHV) {
    /* SAX case */
    SV **enamep = hv_fetch((HV *)SvRV(enamesv), "Name", 4, 0);
    ename = enamep ? (char *)SvPV_nolen(*enamep) : 0;
    SV **attributesp = hv_fetch((HV *)SvRV(enamesv), "Attributes", 10, 0);
    sv = attributesp ? *attributesp : 0;
    itemcnt = 2;
    if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV) {
      attributes = (HV *)SvRV(sv);
    }
  } else {
    /* expat case */
    ename = (char *)SvPV_nolen(enamesv);
    itemcnt = items;
  }

  if (!ename)
    XSRETURN_UNDEF;
  enamelen = strlen(ename);
  svp = hv_fetch(phv, "work", 4, 0);
  sv = svp ? *svp : 0;
  if (!(sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV))
    XSRETURN_UNDEF;
  workav = (AV *)SvRV(sv);
  depth = av_len(workav);
  if (depth < 2)
    XSRETURN_UNDEF;

  svp = av_fetch(workav, depth - 2, 0);
  sv = svp ? *svp : 0;
  if (!(sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV))
    XSRETURN_UNDEF;
  knownhv = (HV *)SvRV(sv);

  svp = hv_fetch(knownhv, ename, enamelen, 0);
  ksv = svp ? *svp : 0;
  if (!ksv || !SvOK(ksv))
    {
      PUSHMARK(&ST(-1));
      call_pv("XML::Structured::_handle_start_slow", G_VOID | G_DISCARD);
      XSRETURN_UNDEF;
    }

  svp = av_fetch(workav, depth - 1, 0);
  sv = svp ? *svp : 0;
  if (!(sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV))
    XSRETURN_UNDEF;
  outhv = (HV *)SvRV(sv);

  if (!SvROK(ksv))
    {
      if (attributes ? HvKEYS(attributes) : itemcnt > 2)
	{
	  PUSHMARK(&ST(-1));
	  call_pv("XML::Structured::_handle_start_slow", G_VOID | G_DISCARD);
	  XSRETURN_UNDEF;
	}
      if (SvTRUE(ksv))
	{
	  /* array */
	  AV *nav;
	  svp = hv_fetch(outhv, ename, enamelen, 1);
	  if (!svp)
	    croak("internal error, could not create hash element\n");
	  sv = *svp;
	  if (!SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVAV)
	    {
	      nav = newAV();
	      SvREFCNT_dec(sv);
	      *svp = newRV_noinc((SV *)nav);
	    }
	  else
	    nav = (AV *)SvRV(sv);
	  chrsv = newSVpv("", 0);
	  av_push(nav, chrsv);
	}
      else
	{
	  if (hv_exists(outhv, ename, enamelen))
	    croak("element '%s' must be singleton\n", ename);
	  chrsv = newSVpv("", 0);
	  (void)hv_store(outhv, ename, enamelen, chrsv, 0);
	}
      av_push(workav, newRV_noinc((SV *)newHV()));
      av_push(workav, newSV(0));
#if 0
      av_push(workav, newRV_inc(chrsv));
#else
      av_push(workav, SvREFCNT_inc(chrsv));
#endif
    }
  else if (SvTYPE(SvRV(ksv)) == SVt_PVAV)
    {
      int i;
      HV *enthv;
      SV *entsv, *knownsv;
      AV *kav = (AV *)SvRV(ksv);
      svp = av_fetch(kav, 0, 0);
      ksv = svp ? *svp : 0;
      svp = av_fetch(kav, 1, 0);
      sv = svp ? *svp : 0;
      if (!(sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV))
	croak("internal error, ksv does not exist\n");
      knownsv = sv;
      knownhv = (HV *)SvRV(sv);

      if (SvTRUE(ksv))
	{
	  /* array */
	  AV *nav;
	  svp = hv_fetch(outhv, ename, enamelen, 1);
	  if (!svp)
	    croak("internal error, could not create hash element\n");
	  sv = *svp;
	  if (!SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVAV)
	    {
	      nav = newAV();
	      SvREFCNT_dec(sv);
	      *svp = newRV_noinc((SV *)nav);
	    }
	  else
	    nav = (AV *)SvRV(sv);
	  enthv = newHV();
	  entsv = newRV_noinc((SV *)enthv);
	  av_push(nav, entsv);
	}
      else
	{
	  if (hv_exists(outhv, ename, enamelen))
	    croak("element '%s' must be singleton\n", ename);
	  enthv = newHV();
	  entsv = newRV_noinc((SV *)enthv);
	  (void)hv_store(outhv, ename, enamelen, entsv, 0);
	}

      if (attributes)
	hv_iterinit(attributes);
      for (i = 2; ; i += 2)
	{
	  const char *aname;
	  SV *avalue;
	  I32 anamelen;
	  if (attributes) {
	    /* SAX case */
	    HE *he = hv_iternext(attributes);
	    SV *atref, **tmpp;
	    if (!he)
	      break;
	    atref = hv_iterval(attributes, he);
	    if (!atref || !SvROK(atref) || SvTYPE(SvRV(atref)) != SVt_PVHV)
	      continue;
	    tmpp = hv_fetch((HV *)SvRV(atref), "Name", 4, 0);
	    if (!tmpp || !*tmpp)
	      continue;
	    aname = SvPV_nolen_const(*tmpp);
	    tmpp = hv_fetch((HV *)SvRV(atref), "Value", 5, 0);
	    if (!tmpp || !*tmpp)
	      continue;
	    avalue = *tmpp;
	  } else {
	    /* expat case */
	    if (i >= itemcnt)
	      break;
	    aname = SvPV_nolen_const(ST(i));
	    avalue = ST(i + 1);
	  }
	  anamelen = strlen(aname);
	  if (handlechar_bytes)
	    SvUTF8_off(avalue);
	  svp = hv_fetch(knownhv, aname, anamelen, 0);
	  ksv = svp ? *svp : 0;
	  if (!ksv || !SvOK(ksv))
	    croak("element '%s' contains unknown attribute '%s'\n", ename, aname);
	  if (SvROK(ksv))
	    croak("attribute '%s' in '%s' must be element\n", aname, ename);
	  if (SvTRUE(ksv))
	    {
	      /* array */
	      AV *nav;
	      svp = hv_fetch(enthv, aname, anamelen, 1);
	      if (!svp)
		croak("internal error, could not create hash element\n");
	      sv = *svp;
	      if (!SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVAV)
		{
		  nav = newAV();
		  SvREFCNT_dec(sv);
		  *svp = newRV_noinc((SV *)nav);
		}
	      else
		nav = (AV *)SvRV(sv);
	      av_push(nav, SvREFCNT_inc(avalue));
	    }
	  else
	    {
	      if (hv_exists(enthv, aname, anamelen))
		croak("attribute '%s' must be singleton\n", aname);
	      (void)hv_store(enthv, aname, anamelen, SvREFCNT_inc(avalue), 0);
	    }
	}
      av_push(workav, SvREFCNT_inc(knownsv));
      av_push(workav, SvREFCNT_inc(entsv));
      if (hv_exists(knownhv, "_content", 8))
	{
	  SV *contsv = newSVpv("", 0);
	  (void)hv_store(enthv, "_content", 8, contsv, 0);
#if 0
	  av_push(workav, newRV_inc(contsv));
#else
	  av_push(workav, SvREFCNT_inc(contsv));
#endif
	}
      else
        av_push(workav, newSV(0));
    }
  else
    {
      PUSHMARK(&ST(-1));
      call_pv("XML::Structured::_handle_start_slow", G_VOID | G_DISCARD);
      XSRETURN_UNDEF;
    }


void
_handle_end(HV *phv, ...)
CODE:
  SV *sv, *outsv, **svp;
  svp = hv_fetch(phv, "work", 4, 0);
  sv = svp ? *svp : 0;
  if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)
    {
      AV *av = (AV *)SvRV(sv);
      I32 depth = av_len(av);
      if (depth >= 2)
	{
	  svp = av_fetch(av, depth - 1, 0);
	  outsv = svp ? *svp : 0;
	  if (outsv && SvROK(outsv))
	    {
	      svp = av_fetch(av, depth, 0);
	      sv = svp ? *svp : 0;
	      if (sv && SvOK(sv))
		{
		  const char *s;
		  I32 dlen, dlenorig;

		  if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PV)
		    sv = (SV *)SvRV(sv);

		  /* trim spaces, should only do this when we have either
		   * seen a sub-element or the dtd specifies one */
		  dlen = dlenorig = SvCUR(sv);
		  if (dlen)
		    {
		      s = SvPVX(sv) + dlen - 1;
		      while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n')
			{
			  s--;
			  if (!--dlen)
			    break;
			}
		      if (dlen != dlenorig)
			{
			  SvCUR_set(sv, dlen);
			  dlenorig = dlen;
			}
		    }
		  if (dlen)
		    {
		      s = SvPVX(sv);
		      while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n')
			{
			  s++;
			  if (!--dlen)
			    break;
			}
		      if (dlen != dlenorig)
			sv_chop(sv, s);
		    }
		  if (!dlen)
		    {
		      /* trimmed everything, delete _content element */
		      HV *hv = (HV *)SvRV(outsv);
		      (void)hv_delete(hv, "_content", 8, G_DISCARD);
		    }
		}
	    }
	  av_fill(av, depth - 3);
	}
    }

