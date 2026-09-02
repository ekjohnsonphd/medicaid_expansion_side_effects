#show: doc => poster(
$if(title)$title: [$title$],$endif$
$if(subtitle)$subtitle: [$subtitle$],$endif$
$if(venue)$venue: [$venue$],$endif$
$if(by-author)$authors: ($for(by-author)$[$it.name.literal$],$endfor$),$endif$
$if(takeaway)$takeaway: [$takeaway$],$endif$
$if(takeaway-sub)$takeaway-sub: [$takeaway-sub$],$endif$
$if(cols)$cols: $cols$,$endif$
doc,
)
