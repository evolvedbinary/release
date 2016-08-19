xquery version "3.1";

(:
 : frus.xq XQuery Module - to facilitate writing xqueries that deal with FRUS TEI files
 : and make it easier to write new queries.
 :
 : To include in sandbox or stored queries, include this in the query prolog:
 : import module namespace frus = "http://history.state.gov/xquery/frus" at "xmldb:exist:///db/history/modules/frus.xq";
 :)

module namespace frus = "http://history.state.gov/ns/xquery/frus";

import module namespace render = "http://history.state.gov/ns/xquery/tei-render" at "tei-render.xql";
import module namespace util= "http://exist-db.org/xquery/util";

declare namespace functx = "http://www.functx.com";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(: TODO:
 : - continue refactoring historicaldocuments.xq to remove repetitive code that can be centralized here
 : - add functions that will facilitate building more sophisticated queries
 : - add comments/xqdocs for each function
 :)

(:~
 : Removes descendant elements from an XML node, based on name
 :
 : @author  Priscilla Walmsley, Datypic
 : @version 1.0
 : @see     http://www.xqueryfunctions.com/xq/functx_remove-elements-deep.html
 : @param   $nodes root(s) to start from
 : @param   $names the names of the elements to remove
 :)
declare function functx:remove-elements-deep
  ( $nodes as node()* ,
    $names as xs:string* )  as node()* {

   for $node in $nodes
   return
     if ($node instance of element())
     then if (functx:name-test(name($node),$names))
          then ()
          else element { node-name($node)}
                { $node/@*,
                  functx:remove-elements-deep($node/node(), $names)}
     else if ($node instance of document-node())
     then functx:remove-elements-deep($node/node(), $names)
     else $node
 } ;

(:~
 : Whether a name matches a list of names or name wildcards
 :
 : @author  Priscilla Walmsley, Datypic
 : @version 1.0
 : @see     http://www.xqueryfunctions.com/xq/functx_name-test.html
 : @param   $testname the name to test
 : @param   $names the list of names or name wildcards
 :)
declare function functx:name-test
  ( $testname as xs:string? ,
    $names as xs:string* )  as xs:boolean {

$testname = $names
or
$names = '*'
or
functx:substring-after-if-contains($testname,':') =
   (for $name in $names
   return substring-after($name,'*:'))
or
substring-before($testname,':') =
   (for $name in $names[contains(.,':*')]
   return substring-before($name,':*'))
 } ;

(:~
 : Performs substring-after, returning the entire string if it does not contain the delimiter
 :
 : @author  Priscilla Walmsley, Datypic
 : @version 1.0
 : @see     http://www.xqueryfunctions.com/xq/functx_substring-after-if-contains.html
 : @param   $arg the string to substring
 : @param   $delim the delimiter
 :)
declare function functx:substring-after-if-contains
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string? {

   if (contains($arg,$delim))
   then substring-after($arg,$delim)
   else $arg
 } ;

(: eXist db path to FRUS XML files:)
declare variable $frus:VOLUMES-PATH := '/db/apps/frus/volumes/';
	(: TODO we should be able to use $paho:MAINCOLLECTION but not sure why this import isn't working :)

(: absolute path to section of website containing FRUS :)
declare variable $frus:FRUS-URL := '/historicaldocuments/';

(: static file location values: local, hsg, or s3 :)
declare variable $frus:STATIC-FILE-LOCATION := 's3';

(: local eXist db path to FRUS PDF files :)
declare variable $frus:PDF-DB-PATH := '/db/fruspageimages/';

(: local eXist db path to FRUS page images :)
declare variable $frus:PAGEIMAGES-DB-PATH := '/db/fruspageimages/';

(: URL path to PDFs :)
declare variable $frus:PDF-URL-PATH :=
    if ($frus:STATIC-FILE-LOCATION eq 'local') then '/historicaldocuments/'
    else if ($frus:STATIC-FILE-LOCATION eq 's3') then '//s3.amazonaws.com/static.history.state.gov/frus/'
    else (: hsg :) '//history.state.gov/historicaldocuments/'
;

(: URL path to PDFs :)
declare variable $frus:PAGEIMAGES-URL-PATH :=
    if ($frus:STATIC-FILE-LOCATION eq 'local') then '/historicaldocuments/'
    else if ($frus:STATIC-FILE-LOCATION eq 's3') then '//s3.amazonaws.com/static.history.state.gov/frus/'
    else (: hsg :) '//history.state.gov/historicaldocuments/'
;

(: gets document node of a volume from its unique volume id :)
(: TODO: make changes necessary to be able to remove * :)
declare function frus:volume($volumeids as xs:string+) as document-node()* {
    for $volumeid in $volumeids
    return doc(concat($frus:VOLUMES-PATH, $volumeid, '.xml'))
};

(: TODO: make changes necessary to be able to remove * :)
declare function frus:volumes() as element(tei:TEI)* {
    collection($frus:VOLUMES-PATH)/tei:TEI
};

declare function frus:volumes($partialvolumeid as xs:string) as element(tei:TEI)* {
    for $volume in frus:volumes()//tei:idno[@type='frus'][contains(., $partialvolumeid)]
    let $volumeid := frus:volumeid($volume)
    order by $volumeid
    return $volume
};

declare function frus:volumeid($id as node()) {
    substring-before(util:document-name($id), '.xml')
};

declare function frus:volumeids() {
    for $volume in frus:volumes()
    let $volumeid := frus:volumeid($volume)
    order by $volumeid
    return $volumeid
};

declare function frus:volumeids($partialvolumeid as xs:string) {
    for $volume in frus:volumes()//tei:idno[@type='frus'][contains(., $partialvolumeid)]
    let $volumeid := frus:volumeid($volume)
    order by $volumeid
    return $volumeid
};

declare function frus:trace($ids as node()+) {
    for $id in $ids
    let $volumeid := frus:volumeid($id)
    let $xmlid := $id/ancestor::*[@xml:id][1]/@xml:id/string()
    return concat($volumeid, '/', $xmlid)
};

declare function frus:trace-count($hits as node()+) {
    let $trace := frus:trace($hits)
    for $hit in distinct-values($trace)
    return concat($hit, ': ', count($hit[. = $trace]))
};

declare function frus:exists-volume($volumeid as xs:string) as xs:boolean {
    exists(collection('/db/apps/frus/bibliography')/volume[@id eq $volumeid])
};

declare function frus:exists-volume-in-db($volumeid as xs:string) as xs:boolean {
    exists(frus:volume($volumeid)//tei:idno[@type='frus'][. eq $volumeid])
};

declare function frus:exists-fulltext-volume-in-db($volumeid as xs:string) as xs:boolean {
    exists(frus:volume($volumeid)//tei:body/tei:div)
};

declare function frus:fulltext-volumes-in-db() as xs:string+ {
    for $volume in collection($frus:VOLUMES-PATH)/tei:TEI[.//tei:body/tei:div]
    return
        frus:volumeid($volume)
};

declare function frus:volume-title($volumeids as xs:string+, $type as xs:string) as text()* {
    for $volumeid in $volumeids
    order by $volumeid
    return
    	if (frus:exists-volume-in-db($volumeid)) then
    	    frus:volume($volumeid)//tei:title[@type = $type][1]/text()
        else
            collection('/db/apps/frus/bibliography')/volume[@id eq $volumeid]/title[@type eq $type]/text()
};

declare function frus:volume-title($volumeids as xs:string+) as text()* {
    for $volumeid in $volumeids
    order by $volumeid
    return
    	if (frus:exists-volume-in-db($volumeid)) then
    	    frus:volume($volumeid)//tei:title[@type = 'complete']/text()
        else
            collection('/db/apps/frus/bibliography')/volume[@id eq $volumeid]/title[@type eq 'complete']/text()
};

declare function frus:exists-id($volumeid as xs:string, $id as xs:string) as xs:boolean {
    exists(frus:volume($volumeid)/id($id))
};

declare function frus:id($volumeid as xs:string, $id as xs:string) as element() {
    frus:volume($volumeid)/id($id)
};

declare function frus:type-of-id($volumeid as xs:string, $id as xs:string) as xs:string {
    string(frus:volume($volumeid)/id($id)/@type)
};

declare function frus:pdf-collection($volumeid as xs:string) as xs:string {
    concat($frus:PDF-DB-PATH, $volumeid, '/pdf/')
};

declare function frus:pdf-filename($volumeid as xs:string) as xs:string {
	concat($volumeid, '.pdf')
};

declare function frus:exists-pdf($volumeid as xs:string) as xs:boolean {
    if ($frus:STATIC-FILE-LOCATION = 'local') then
        util:binary-doc-available(frus:pdf-db-path($volumeid))
    else (: if ($frusx:STATIC-FILE-LOCATION = 's3') then :)
        let $collection := '/db/history/data/s3-resources/static.history.state.gov/frus/'
        let $pdf-filename := concat($volumeid, '.pdf')
        return
            exists(collection($collection)//filename[. = $pdf-filename])
};

declare function frus:volumes-with-ebooks() {
    for $hit in collection('/db/history/data/s3-resources/static.history.state.gov/frus/')//filename[ends-with(., '.epub')]
    return
        substring-before($hit, '.epub')
};

declare function frus:volumes-with-single-pdfs() {
    for $hit in collection('/db/history/data/s3-resources/static.history.state.gov/frus/')//filename[ends-with(.,'.pdf')][starts-with(., 'frus')]
    return
        substring-before($hit, '.pdf')
};

declare function frus:volumes-with-ebooks-or-single-pdfs() {
    distinct-values((frus:volumes-with-ebooks(), frus:volumes-with-single-pdfs()))
};

declare function frus:exists-ebook($volumeid as xs:string) as xs:boolean {
    if ($frus:STATIC-FILE-LOCATION = ('local', 'hsg')) then
        exists(doc('/db/history/data/historicaldocuments/ebooks.xml')//ebook[@id eq $volumeid])
    else (: if ($frusx:STATIC-FILE-LOCATION = 's3') then :)
        let $collection := concat('/db/history/data/s3-resources/static.history.state.gov/frus/', $volumeid, '/ebook')
        let $epub-filename := concat($volumeid, '.epub')
        return
            exists(collection($collection)//filename[. = $epub-filename])
};

declare function frus:epub-url($volumeid as xs:string) as xs:string {
	concat($frus:PDF-URL-PATH, $volumeid, '/ebook/', $volumeid, '.epub')
};

declare function frus:mobi-url($volumeid as xs:string) as xs:string {
	concat($frus:PDF-URL-PATH, $volumeid, '/ebook/', $volumeid, '.mobi')
};

declare function frus:epub-size($volumeid as xs:string) {
    let $epub := (doc(concat('/db/history/data/s3-resources/static.history.state.gov/frus/', $volumeid, '/ebook/resources.xml'))//filename[ends-with(., '.epub')]/parent::resource)[1]
    let $size := $epub//size
    return
        frus:bytes-to-readable($size)
};

declare function frus:mobi-size($volumeid as xs:string) {
    let $mobi := (doc(concat('/db/history/data/s3-resources/static.history.state.gov/frus/', $volumeid, '/ebook/resources.xml'))//filename[ends-with(., '.mobi')]/parent::resource)[1]
    let $size := $mobi//size
    return
        frus:bytes-to-readable($size)
};

(: returns the size of a file in kb or mb :)
declare function frus:file-size($collection as xs:string, $filename as xs:string) as xs:string {
    let $sizeinbytes := xmldb:size($collection, $filename)
    return frus:bytes-to-readable($sizeinbytes)
};

declare function frus:bytes-to-readable($bytes as xs:integer) {
    if ($bytes gt 1000000) then
        concat((round($bytes div 10000) div 100), 'mb')
    else if ($bytes gt 1000) then
        concat(round($bytes div 1000), 'kb')
    else ()
};

declare function frus:ebook-last-updated($volumeid as xs:string) {
    let $epub-filename := concat($volumeid, '.epub')
    let $epub := (doc(concat('/db/history/data/s3-resources/static.history.state.gov/frus/', $volumeid, '/ebook/resources.xml'))//filename[ends-with(., '.epub')]/parent::resource)[1]
    return
        $epub/last-modified/string()
};

declare function frus:exists-doc-pdf($volumeid, $document) as xs:boolean {
    if ($frus:STATIC-FILE-LOCATION = ('local', 'hsg')) then
        util:binary-doc-available(concat(frus:pdf-collection($volumeid), '/', $document, '.pdf'))
    else (: if ($frusx:STATIC-FILE-LOCATION = 's3') then :)
        collection(concat('/db/history/data/s3-resources/static.history.state.gov/frus/', $volumeid, '/pdf/'))//filename = concat($document, '.pdf')
};

declare function frus:pdf-db-path($volumeid as xs:string) as xs:string {
	concat(frus:pdf-collection($volumeid), frus:pdf-filename($volumeid))
};

declare function frus:pdf-url($volumeid as xs:string) as xs:string {
	concat($frus:PDF-URL-PATH, $volumeid, if ($frus:STATIC-FILE-LOCATION eq 's3') then () else '/media', '/pdf/', $volumeid, '.pdf')
};

declare function frus:page-image-url($id as element(tei:pb)) as xs:string {
	let $volumeid := frus:volumeid($id)
	let $facs := $id/@facs/string()
	return
	    concat($frus:PAGEIMAGES-URL-PATH, $volumeid, if ($frus:STATIC-FILE-LOCATION eq 's3') then () else '/media', '/medium/', $facs, '.png')
};

declare function frus:pdf-size($volumeid as xs:string) {
    if ($frus:STATIC-FILE-LOCATION = 'local') then
        frus:file-size(frus:pdf-collection($volumeid), frus:pdf-filename($volumeid))
    else (: if ($frusx:STATIC-FILE-LOCATION = 's3') then :)
        frus:bytes-to-readable(collection('/db/history/data/s3-resources/static.history.state.gov/frus/')//filename[. eq frus:pdf-filename($volumeid)]/following-sibling::size)
};

declare function frus:isbn($volumeid as xs:string) as text()* {
	frus:volume($volumeid)//tei:idno[@type = ('isbn-10','isbn-13')]/text()
};

declare function frus:isbn-url($isbn as xs:string) as xs:string {
    concat('http://www.worldcat.org/search?q=isbn%3A', $isbn)
};

declare function frus:documents() as element(tei:div)* {
	collection($frus:VOLUMES-PATH)//tei:div[@type='document' and @xml:id]
};

declare function frus:documents($volumeids as xs:string+) as element(tei:div)+ {
	let $volumes := frus:volume($volumeids)
	return $volumes//tei:div[@type='document' and @xml:id]
};

declare function frus:documents($volumeid as xs:string, $id as xs:string) as element(tei:div)* {
	frus:id($volumeid, $id)//tei:div[@type='document' and @xml:id]
};

declare function frus:document-number($volumeid as xs:string, $id as xs:string) as xs:string {
    frus:id($volumeid, $id)/@n/string()
};

declare function frus:document-number($id as element(tei:div)) as xs:string {
    $id/@n/string()
};

declare function frus:document-id($id as element(tei:div)) as xs:string {
    $id/@xml:id/string()
};

declare function frus:get-citation($id as element()) as xs:string {
    let $volume := frus:volumeid($id)
    let $volumetitle := frus:volume-title($volume, 'complete')
    let $subvolumeinfo :=
        if ($id/self::tei:div) then
            if ($id/@type eq 'document') then
                concat ('Document ', $id/@n)
            else if ($id/@type = ('section', 'chapter', 'compilation', 'subchapter')) then
                $id/tei:head/text()
            else ()
        else if (name($id) eq 'pb' and $id/@n) then
            let $ancestor := ($id/following-sibling::element()[1][self::tei:div], $id/ancestor::tei:div[1])[1]
            let $ancestorcitation :=
                if ($ancestor/@type eq 'document') then
                    concat('Document ', $ancestor/@n, ', ')
                else if ($ancestor/@type = ('section', 'chapter', 'compilation', 'subchapter')) then
                    concat(frus:head-sans-note($ancestor), ', ')
                else ()
            return
                concat($ancestorcitation, 'Page ', $id/@n)
        else ()
    let $citation := string-join(($volumetitle, $subvolumeinfo), ', ')
    return $citation
};

(: TODO: make changes necessary to be able to remove * :)
declare function frus:source-note($id as element(tei:div)) as element(tei:note)* {
    ($id//tei:note[@type='source'])[1]
};

declare function frus:lb-to-whitespace($node) {
    for $n in $node/node()
    return
        typeswitch ($n)
            case element(tei:lb) return ' '
            case element() return element { name($n) } { frus:lb-to-whitespace($n) }
            default return
                $n
};

declare function frus:head-sans-note($id as element(tei:div)) as xs:string {
    let $sans-note := functx:remove-elements-deep($id/tei:head[1], "note")
    let $lb-to-whitespace := frus:lb-to-whitespace($sans-note)
    return
        normalize-space(string-join($lb-to-whitespace))
};

(: TODO: make changes necessary to be able to remove * :)
declare function frus:dateline($id as element(tei:div)) as element(tei:dateline)* {
    let $dateline := ($id//tei:dateline)[1] (: frus1952-54/d414 has two datelines - the second belonging to an attachment :)
    return
        functx:remove-elements-deep($dateline, 'note')
};

declare function frus:document-summary($id as element(tei:div)) as element(tei:note)* {
    if ($id//tei:note/@type='summary') then
        $id//tei:note[@type='summary']
    else ()
};

declare function frus:document-head-sans-number($id as element(tei:div)) as xs:string {
    let $head := frus:head-sans-note($id)
    let $newtitle :=
        if (matches($head, "^\d+a?\.")) then
            replace($head, "^\d+a?\.", "")
        else if (matches($head, "^No. \d+a?")) then
            replace($head, "^No. \d+a?", "")
        else
            $head
    return
        $newtitle
};

declare function frus:sections($volumeid as xs:string) {
	frus:volume($volumeid)//tei:div[@type = ('section', 'compilation', 'chapter')]
};

declare function frus:url($volumeid as xs:string) as xs:string {
	concat($frus:FRUS-URL, $volumeid)
};

declare function frus:url($volumeid as xs:string, $id as xs:string) as xs:string {
	concat($frus:FRUS-URL, $volumeid, '/', $id)
};

declare function frus:toc($volume as xs:string) {
	frus:toc($volume, ())
};

(: whole volume TOC :)
declare function frus:toc($volume as xs:string, $id-to-highlight as xs:string?) {
    let $vol := frus:volume($volume)
    return
    	<div class="toc" xmlns="http://www.w3.org/1999/xhtml">
            <ul>{frus:toc-passthru($vol, $id-to-highlight)}</ul>
        </div>
};

(: volume of just the section id and deeper :)
declare function frus:toc-inner($volume as xs:string, $id as xs:string?) {
    let $inner-section := frus:id($volume, $id)
    return
    	<div class="toc" xmlns="http://www.w3.org/1999/xhtml">
            <ul>{frus:toc-passthru($inner-section, $id)}</ul>
        </div>
};

declare function frus:toc-passthru($node as item()*, $id-to-highlight as xs:string?) {
    (: if we're given a div, dig deeper :)
    if ($node/self::tei:div) then
        $node/tei:div ! frus:toc-div(., $id-to-highlight)
    (: if we're not given a div - presumably a tei:TEI or tei:text element - find the topmost divs :)
    else
        $node//tei:div[not(ancestor::tei:div)] ! frus:toc-div(., $id-to-highlight)
};

(: handles divs for TOCs :)
declare function frus:toc-div($node as element(tei:div), $id-to-highlight as xs:string?) {
    let $sections-to-suppress := ('toc')
    return
    (: we only show certain divs :)
    if (not($node/@xml:id = $sections-to-suppress) and not($node/@type = 'document')) then
        <li xmlns="http://www.w3.org/1999/xhtml">
            {
            let $href := attribute href { concat('/historicaldocuments/', frus:volumeid($node), '/', $node/@xml:id) }
            let $highlight := if ($node/@xml:id = $id-to-highlight) then attribute class {'highlight'} else ()
            return
                <a>
                    {
                    $href,
                    $highlight,
                    frus:toc-head($node/tei:head[1])
                    }
                </a>
            ,

            if ($node/tei:div/@type = 'document') then
                concat(
                    ' (Document',
                    let $child-docs := $node/tei:div[@type = 'document']
                    let $first := $child-docs[1]/@n
                    let $last := $child-docs[last()]/@n
                    return
                        if ($first = $last) then
                            concat(' ', $first)
                        else
                            concat('s ', $first, '-', $last)
                    , ')'
                    )
            else
                ()
            ,
            if ($node/tei:div/@type = 'document' and not($node/tei:div/@type = 'document')) then ()
            else
                <ul>
                    {
                        frus:toc-passthru($node, $id-to-highlight)
                    }
                </ul>
            }
        </li>
    else
        ()
};

(: handles heads for TOCs :)
declare function frus:toc-head($node as element(tei:head)) {
    let $head-sans-note := if ($node//tei:note) then functx:remove-elements-deep($node, 'note') else $node
    return
        render:recurse($head-sans-note, ())
};

declare function frus:toc-link($node, $id-to-highlight) {
    let $id := $node/@xml:id
    let $vol-id := frus:volumeid($node)
    return
        concat($vol-id, '/', $id)
};

declare function frus:toc-render($volume as xs:string, $id as xs:string, $highlightcurrent, $view) {
    (: TODO: make nested lists valid XHTML :)
    for $sect in frus:sections($volume)[not(parent::tei:div[@type='compilation'])]
	let $type := $sect/@type
	let $sectid := $sect/@xml:id
    let $secttitle := $sect/tei:head[1]
    let $secttitletext := data(functx:remove-elements-deep($secttitle, "note"))
    let $currentsection :=
        (: is $id a document in a chapter/compilation? :)
        if (frus:id($volume, $id)/self::tei:div[@type='document']) then
            frus:id($volume, $id)/parent::tei:div/tei:head[1]
        (: or is $id a chapter/compilation itself? :)
        else
            frus:id($volume, $id)/tei:head[1]
    let $highlightstatus :=
    	if ($highlightcurrent) then
    		if ($secttitle eq $currentsection) then true()
    		else ()
    	else ()
    let $viewstatus :=
		if ($view) then
		    (concat("/", $view))
		else ()
	return
		if ($type = ('section', 'compilation')) then
			(: 1st tier: for sections and compilations :)
			<li xmlns="http://www.w3.org/1999/xhtml">{ frus:toc-link($secttitletext, $volume, $sectid, $viewstatus, $highlightstatus) }
				{
				if ($sect/tei:div[@type='chapter']) then
					(: 2nd tier: for chapters contained inside sections and compilations :)
					<ul class="sidenavbottom">
						{
						for $chapter in $sect/tei:div[@type='chapter']
						let $chapterid := $chapter/@xml:id/string()
						let $chaptertitle := $chapter/tei:head[1]
						let $chaptertitletext := data(functx:remove-elements-deep($chaptertitle, "note"))
					    let $currentchapter :=
					        (: is $id a document in a chapter/compilation? :)
					        if (frus:id($volume, $id)/self::tei:div[@type='document']) then
					            frus:id($volume, $id)/parent::tei:div/tei:head[1]
					        (: or is $id a chapter/compilation itself? :)
					        else
					            frus:id($volume, $id)/tei:head[1]
		                let $highlightstatus :=
						    if ($highlightcurrent) then
						    	if ($chaptertitle eq $currentchapter) then true()
						    	else ()
						    else ()
						return
							<li>{ frus:toc-link($chaptertitletext, $volume, $chapterid, $viewstatus, $highlightstatus) }</li>
						}
					</ul>
				else ()
				}
			</li>
		else if ($sect/parent::tei:div[@type='compilation']) then
			(: if chapter is part of a compilation, don't show it :)
			()
		else
			(: if chapter isn't encapsulated in a compilation, show it :)
			<li xmlns="http://www.w3.org/1999/xhtml">{ frus:toc-link($secttitletext, $volume, $sectid, $viewstatus, $highlightstatus) }</li>
};

declare function frus:toc-link($secttitletext, $volume, $sectid, $viewstatus, $highlightstatus) {
	if ($highlightstatus) then
		(: highlight :)
		( attribute class {"sidebarhighlighted"}, $secttitletext )
	else
		<a xmlns="http://www.w3.org/1999/xhtml" href="{frus:url($volume, $sectid)}{$viewstatus}">{$secttitletext}</a>
};

declare function frus:editor-role-to-label($role as xs:string, $form as xs:string) as xs:string {
    let $item := doc('/db/apps/frus/code-tables/editor-role-codes.xml')//item[value = $role]
    let $label :=
        if ($form = 'plural') then
            $item/label/plural
        else (: if ($form = 'plural') then :)
            $item/label/singular
    return
        $label/string()
};

declare function frus:editor-roles() as xs:string+ {
    doc('/db/apps/frus/code-tables/editor-role-codes.xml')//value
};
