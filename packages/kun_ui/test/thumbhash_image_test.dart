import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/thumbhash_image.dart'
    show ThumbHashRgba, tryDecodeThumbHash;

typedef _Vector = ({
  String name,
  String hash,
  int width,
  int height,
  String rgbaB64,
});

const List<_Vector> _vectors = <_Vector>[
  (
    name: 'docs-banner',
    hash: 'eBeCA4AmyAaYeIcLy20KVwg3inaCelc=',
    width: 32,
    height: 19,
    rgbaB64:
        '4dXwAOHV8ADh1fAA4dXwAOHV8Brh1fA04dXwTOHV8F/h1fBs4dXwcuHV8HHh1fBr4dXwYuHV8Ffh1fBN4dXwRuHV8ELh1fBD4dXwRuHV8Ezh1fBS4dXwVuHV8Fbh1fBR4dXwR+HV8Dfh1fAk4dXwDeHV8ADh1fAA4dXwAOHV8ADh1fAA4dXwAOHV8ADh1fAN4dXwJ+HV8ELh1fBb4dXwbuHV8Hzh1fCC4dXwgeHV8Hvh1fBy4dXwaOHV8F7h1fBX4dXwU+HV8FPh1fBX4dXwXOHV8GLh1fBm4dXwZeHV8GDh1fBV4dXwReHV8DHh1fAa4dXwBOHV8ADh1fAA4dXwAOHV8ADh1fAA4dXwDOHV8CTh1fA/4dXwWuHV8HPh1fCH4dXwleHV8Jzh1fCc4dXwl+HV8I7h1fCE4dXweuHV8HPh1fBw4dXwcOHV8HPh1fB44dXwfeHV8IDh1fB/4dXweeHV8G7h1fBd4dXwSOHV8DDh1fAZ4dXwBeHV8ADh1fAA4dXwCeHV8BPh1fAk4dXwPOHV8Fjh1fB04dXwjuHV8KPh1fCx4dXwueHV8Lrh1fC24dXwruHV8KTh1fCb4dXwlOHV8JHh1fCR4dXwlOHV8Jjh1fCc4dXwnuHV8J3h1fCV4dXwieHV8Hfh1fBg4dXwSOHV8DDh1fAb4dXwDOHV8ATh1fAb4dXwJOHV8Dbh1fBP4dXwa+HV8Ijh1fCj4dXwueHV8Mjh1fDR4dXw0+HV8NDh1fDJ4dXwwOHV8Lfh1fCx4dXwreHV8K3h1fCw4dXwtOHV8Lfh1fC44dXwteHV8K3h1fCf4dXwjOHV8HTh1fBb4dXwQuHV8C3h1fAd4dXwFOHV8CHh1fAr4dXwPeHV8Fbh1fBz4dXwkeHV8K3h1fDE4dXw1eHV8N/h1fDi4dXw3+HV8Nnh1fDR4dXwyeHV8MPh1fDA4dXwwOHV8MLh1fDF4dXwyOHV8Mjh1fDE4dXwu+HV8Kzh1fCX4dXwf+HV8GTh1fBK4dXwNOHV8CTh1fAb4dXwHeHV8Cfh1fA54dXwU+HV8HDh1fCP4dXwq+HV8MPh1fDV4dXw4OHV8OTh1fDi4dXw3eHV8Nbh1fDP4dXwyeHV8Mbh1fDG4dXwyeHV8Mzh1fDO4dXwzuHV8Mnh1fC+4dXwruHV8Jnh1fB/4dXwZOHV8Enh1fAy4dXwIuHV8Bnh1fAR4dXwG+HV8C7h1fBH4dXwZeHV8ITh1fCh4dXwuuHV8Mzh1fDY4dXw3eHV8Nzh1fDY4dXw0eHV8Mrh1fDF4dXww+HV8MPh1fDG4dXwyeHV8Mvh1fDK4dXwxeHV8Lrh1fCp4dXwk+HV8Hnh1fBd4dXwQuHV8Cvh1fAZ4dXwEOHV8APh1fAN4dXwIOHV8Drh1fBY4dXwd+HV8JTh1fCt4dXwwOHV8Mzh1fDR4dXw0eHV8M3h1fDH4dXwweHV8L3h1fC74dXwvOHV8L/h1fDC4dXwxOHV8MTh1fC+4dXws+HV8KLh1fCM4dXwceHV8FXh1fA64dXwIuHV8BHh1fAH4dXwAOHV8ATh1fAX4dXwMOHV8E7h1fBt4dXwiuHV8KPh1fC14dXwweHV8Mfh1fDH4dXww+HV8L3h1fC34dXwtOHV8LLh1fC04dXwt+HV8Lvh1fC+4dXwvuHV8Lnh1fCu4dXwneHV8Ifh1fBs4dXwUOHV8DXh1fAd4dXwDOHV8APh1fAA4dXwAeHV8BTh1fAt4dXwSuHV8Gjh1fCF4dXwneHV8K/h1fC64dXwv+HV8L/h1fC74dXwteHV8LDh1fCs4dXwq+HV8K3h1fCx4dXwtuHV8Lrh1fC64dXwtuHV8Kzh1fCc4dXwhuHV8G3h1fBR4dXwNuHV8B/h1fAO4dXwBOHV8ADh1fAF4dXwF+HV8DDh1fBM4dXwaeHV8ITh1fCb4dXwrOHV8Lbh1fC64dXwueHV8LTh1fCu4dXwqeHV8KXh1fCl4dXwp+HV8Kzh1fCy4dXwt+HV8Ljh1fC14dXwreHV8J7h1fCJ4dXwcOHV8FXh1fA74dXwJOHV8BPh1fAK4dXwAuHV8Avh1fAc4dXwNOHV8E/h1fBr4dXwhOHV8Jnh1fCp4dXwseHV8LTh1fCy4dXwrOHV8Kbh1fCg4dXwnOHV8Jzh1fCf4dXwpeHV8Kvh1fCx4dXwtOHV8LLh1fCr4dXwneHV8Irh1fBy4dXwWOHV8D/h1fAp4dXwGeHV8BDh1fAF4dXwDuHV8B/h1fA14dXwT+HV8Gnh1fCA4dXwlOHV8KHh1fCo4dXwqeHV8KXh1fCe4dXwl+HV8JDh1fCN4dXwjOHV8JDh1fCW4dXwnuHV8KXh1fCp4dXwqeHV8KPh1fCX4dXwheHV8G7h1fBW4dXwPeHV8Cjh1fAY4dXwEOHV8ALh1fAK4dXwGuHV8C/h1fBH4dXwYOHV8HXh1fCH4dXwkuHV8Jfh1fCW4dXwkOHV8Ijh1fCA4dXweOHV8HTh1fB04dXweOHV8H/h1fCH4dXwj+HV8JXh1fCW4dXwkuHV8Ifh1fB24dXwYeHV8Erh1fAz4dXwHuHV8A/h1fAH4dXwAOHV8ADh1fAO4dXwIuHV8Djh1fBP4dXwY+HV8HLh1fB84dXwf+HV8Hzh1fB14dXwa+HV8GHh1fBZ4dXwVeHV8FTh1fBY4dXwX+HV8Gnh1fBy4dXweOHV8Hvh1fB44dXwb+HV8GDh1fBM4dXwNeHV8B/h1fAL4dXwAOHV8ADh1fAA4dXwAOHV8ADh1fAQ4dXwJeHV8Drh1fBN4dXwWuHV8GLh1fBj4dXwX+HV8Fbh1fBL4dXwQeHV8Djh1fAz4dXwMuHV8Dbh1fA+4dXwR+HV8FHh1fBZ4dXwXeHV8Fvh1fBT4dXwROHV8DLh1fAc4dXwB+HV8ADh1fAA4dXwAOHV8ADh1fAA4dXwAOHV8ADh1fAT4dXwJ+HV8Djh1fBF4dXwS+HV8Evh1fBG4dXwPOHV8DDh1fAl4dXwG+HV8Bbh1fAV4dXwGeHV8CHh1fAr4dXwNeHV8D7h1fBC4dXwQeHV8Drh1fAs4dXwGuHV8Abh1fAA4dXwAOHV8ADh1fAA4dXwAOHV8ADh1fAA4dXwAOHV8Ajh1fAc4dXwLOHV8Djh1fA+4dXwPeHV8Dfh1fAt4dXwIeHV8BTh1fAL4dXwBeHV8ATh1fAI4dXwEOHV8Bvh1fAl4dXwLuHV8DPh1fAy4dXwK+HV8B7h1fAN4dXwAOHV8ADh1fAA4dXwAOHV8AA=',
  ),
  (
    name: 'opaque-red',
    hash: 'GmoDBwBImT6IeHeId0d3iHiPg6IHC4YF',
    width: 32,
    height: 32,
    rgbaB64:
        '2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/9slO//bJTv/2yU7/w==',
  ),
  (
    name: 'alpha-gradient',
    hash: 'X9WFI5A6UXZQh3hRUBj1io91iIiHiIg=',
    width: 32,
    height: 19,
    rgbaB64:
        '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',
  ),
];

void main() {
  for (final _Vector vector in _vectors) {
    test('decoder matches the JS reference: ${vector.name}', () {
      final ThumbHashRgba? decoded = tryDecodeThumbHash(vector.hash);
      expect(decoded, isNotNull, reason: vector.name);
      expect(decoded!.width, vector.width, reason: vector.name);
      expect(decoded.height, vector.height, reason: vector.name);
      expect(
        base64Encode(decoded.rgba),
        vector.rgbaB64,
        reason: vector.name,
      );
    });
  }

  test('tryDecodeThumbHash rejects invalid input', () {
    expect(tryDecodeThumbHash(''), isNull);
    expect(tryDecodeThumbHash('not-base64!!!'), isNull);
    expect(tryDecodeThumbHash('AA=='), isNull);
  });

  testWidgets('the provider paints the reference size', (tester) async {
    final _Vector vector = _vectors.first;
    final ImageInfo info = (await tester.runAsync(() async {
      final Completer<ImageInfo> loaded = Completer<ImageInfo>();
      KunThumbHashImage(vector.hash)
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (ImageInfo resolved, bool sync) {
                if (!loaded.isCompleted) {
                  loaded.complete(resolved);
                }
              },
              onError: (Object err, StackTrace? stack) {
                if (!loaded.isCompleted) {
                  loaded.completeError(err, stack);
                }
              },
            ),
          );
      return loaded.future;
    }))!;
    expect(info.image.width, vector.width);
    expect(info.image.height, vector.height);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Image(image: KunThumbHashImage(vector.hash)),
      ),
    );
    await tester.pump();
    final RawImage raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull);
    expect(raw.image!.width, vector.width);
    expect(raw.image!.height, vector.height);
  });

  testWidgets('an invalid hash errors through the stream', (tester) async {
    final ImageStream stream = const KunThumbHashImage('not-base64!!!').resolve(
      ImageConfiguration.empty,
    );
    final Completer<Object> error = Completer<Object>();
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool sync) {},
        onError: (Object err, StackTrace? stack) {
          if (!error.isCompleted) {
            error.complete(err);
          }
        },
      ),
    );
    expect(await error.future, isA<StateError>());
  });

  test('equality is by hash', () {
    const KunThumbHashImage a = KunThumbHashImage('abc');
    const KunThumbHashImage b = KunThumbHashImage('abc');
    const KunThumbHashImage c = KunThumbHashImage('def');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
