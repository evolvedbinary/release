xquery version "3.0";

(:~
    A module for generating an EPUB file out of a TEI document.

    Assumes FRUS-like TEI file structure.

    Requires eXist 1.5dev rev. 11085 or later.

    @version 0.1

    @see http://en.wikipedia.org/wiki/EPUB
    @see http://www.ibm.com/developerworks/edu/x-dw-x-epubtut.html
    @see http://code.google.com/p/epubcheck/

:)

module namespace epub = "http://history.state.gov/ns/xquery/epub";

import module namespace compression = "http://exist-db.org/xquery/compression";
import module namespace render = "http://history.state.gov/ns/xquery/tei-render" at "tei-render.xql";
import module namespace frus = "http://history.state.gov/ns/xquery/frus" at "frus.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ncx ="http://www.daisy.org/z3986/2005/ncx/";
declare namespace xhtml="http://www.w3.org/1999/xhtml";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~
    Main function of the EPUB module for assembling EPUB files:
    Takes the elements required for an EPUB document (wrapped in <entry> elements),
    and uses the compression:zip() function to returns a complete EPUB document.

    @param $title the dc:title of the EPUB
    @param $creator the dc:creator of the EPUB
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @param $urn the urn to use in the NCX file
    @param $db-path-to-resources the db path to the required static resources (cover.jpg, stylesheet.css)
    @param $filename the name of the EPUB file, sans file extension
    @return serialized EPUB file

    @see http://demo.exist-db.org/exist/functions/compression/zip
:)
declare function epub:generate-epub($title, $creator, $text, $urn, $db-path-to-resources, $cover, $filename, $options) {
    let $entries :=
        (
        console:log('starting epub:mimetype-entry (1/12)'), epub:mimetype-entry(),
        console:log('starting epub:container-entry (2/12)'), epub:container-entry(),
        console:log('starting epub:content-opf-entry (3/12)'), epub:content-opf-entry($title, $creator, $urn, $text),
        console:log('starting epub:cover-xhtml-entry (4/12)'), epub:cover-xhtml-entry($title),
        console:log('starting epub:title-xhtml-entry (5/12)'), epub:title-xhtml-entry(substring-before(util:document-name($text), '.xml')),
        console:log('starting epub:about-xhtml-entry (6/12)'), epub:about-xhtml-entry(),
        console:log('starting epub:table-of-contents-xhtml-entry (7/12)'), epub:table-of-contents-xhtml-entry($title, $text, true(), $options),
        console:log('starting epub:body-xhtml-entries (8/12) - may take a long time!'), epub:body-xhtml-entries($text, $options),
        console:log('starting epub:stylesheet-entry (9/12)'), epub:stylesheet-entry($db-path-to-resources),
        console:log('starting epub:toc-ncx-entry (10/12)'), epub:toc-ncx-entry($urn, $title, $text),
        console:log('starting epub:cover-entry (11/12)'), epub:cover-entry($cover),
        console:log('starting epub:graphic-entries (12/12)'), epub:graphic-entries($text)
        )
    return
        (
        (:
        console:log(
            <uri-check>{
                $entries !
                    (
                        if (./@type='uri') then
                            (
                                ./string() || ': ' ||
                                util:binary-doc-available(./string())
                            )
                        else ()
                    )
            }</uri-check>
        )
        ,
        console:log(<entries>{$entries ! <entry>{./@name, ./@type, if (./@type='uri') then ./string() else ()}</entry>}</entries>)
        ,
        :)
        compression:zip( $entries, true() )
        )
};

declare variable $epub:cache-collection := '/db/apps/release/epub-cache';

declare function epub:save-frus-epub-to-disk($path-to-tei-document as xs:string, $option as xs:string*, $file-system-output-dir as xs:string) {
    let $vol-id := substring-after(substring-before($path-to-tei-document, '.xml'), 'volumes/')
    let $images-collection := concat($epub:cache-collection, '/', $vol-id, '/images')
    let $item := doc($path-to-tei-document)
    let $titles := $item//tei:titleStmt/tei:title
    let $title := normalize-space(concat($titles[@type eq 'volume'], ' (', string-join(($titles[@type eq 'series'], $titles[@type eq 'sub-series'], $titles[@type eq 'volume-number'])[. ne ''], ', '), ')'))
    let $creator := 'Office of the Historian, Bureau of Public Affairs, United States Department of State'
    let $text := $item//tei:text
    let $urn := concat($vol-id, '-', current-dateTime())
    let $db-path-to-resources := '/db/apps/release/resources'
    let $cover-uri :=
        if (util:binary-doc-available(concat($images-collection, '/', $vol-id, '.jpg'))) then
            concat($images-collection, '/', $vol-id, '.jpg')
        else
            let $href := concat('https://s3.amazonaws.com/static.history.state.gov/frus/', $vol-id, '/covers/', $vol-id, '.jpg')
            let $request := <hc:request href="{$href}" method="head" http-version="1.1"/>
            let $response := hc:send-request($request)
            return
                if ($response/@status eq '200') then
                    let $check-collection :=
                        if (xmldb:collection-available($images-collection)) then
                            ()
                        else
                            (
                            xmldb:create-collection($epub:cache-collection, $vol-id),
                            xmldb:create-collection(concat($epub:cache-collection, '/', $vol-id), 'images')
                            )
                    let $request := <hc:request href="{$href}" method="get" http-version="1.1"/>
                    let $response := hc:send-request($request)
                    let $response-body := $response[2]
                    let $store := xmldb:store($images-collection, 'cover.jpg', $response-body, 'image/jpeg')
                    return
                        concat($images-collection, '/cover.jpg')
                else
                    (
                    concat($db-path-to-resources, '/images/epub-cover.jpg')
                    ,
                    console:log('cover image not found; using default cover image')
                    )
    return
        let $epub-dir := concat($file-system-output-dir, 'epub')
        let $mobi-dir := concat($file-system-output-dir, 'mobi-bound')
        let $filename := concat($vol-id, '.epub')
        let $epub-zip := epub:generate-epub($title, $creator, $text, $urn, $db-path-to-resources, $cover-uri, $filename, $option)
        return
        file:serialize-binary(
            $epub-zip,
            <x>{concat($file-system-output-dir, if ($option = 'mobi') then 'mobi-bound/' else 'epub/', $filename)}</x>
            )
};

(:~
    Helper function, returns the mimetype entry.
    Note that the EPUB specification requires that the mimetype file be uncompressed.
    We can ensure the mimetype file is uncompressed by passing compression:zip() an entry element
    with a method attribute of "store".

    @return the mimetype entry
:)
declare function epub:mimetype-entry() {
    <entry name="mimetype" type="text" method="store">application/epub+zip</entry>
};

(:~
    Helper function, returns the META-INF/container.xml entry.

    @return the META-INF/container.xml entry
:)
declare function epub:container-entry() {
    let $container :=
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
    return
        <entry name="META-INF/container.xml" type="xml">{$container}</entry>
};

declare variable $epub:frus-div-xmlids-to-suppress { ('toc', 'pressrelease', 'summary', 'subseriesvols') };

declare function epub:frus-toc-divs($text as element(tei:text)) {
    let $front := $text/tei:front/tei:div[not(@xml:id = $epub:frus-div-xmlids-to-suppress)]
    let $body := $text/tei:body//tei:div
    let $back := $text/tei:back//tei:div
    return
        ($front, $body, $back)
};

declare function epub:frus-divs($text as element(tei:text)) {
    $text//tei:div[@xml:id and not(@xml:id = $epub:frus-div-xmlids-to-suppress)]
};

(:~
    Helper function, returns the OEBPS/content.opf entry.

    @param $title the dc:title of the EPUB
    @param $creator the dc:creator of the EPUB
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the OEBPS/content.opf entry
:)
declare function epub:content-opf-entry($title, $creator, $urn, $text) {
    let $content-opf :=
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0" unique-identifier="bookid">
            <metadata>
                <dc:title>{$title}</dc:title>
                <dc:creator>{$creator}</dc:creator>
                <dc:identifier id="bookid">{$urn}</dc:identifier>
                <dc:language>en-US</dc:language>
                <meta name="cover" content="cover-image" />
            </metadata>
            <manifest>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="cover" href="cover.html" media-type="application/xhtml+xml"/>
                <item id="title" href="title.html" media-type="application/xhtml+xml"/>
                <item id="about-epub" href="about-epub.html" media-type="application/xhtml+xml"/>
                <item id="table-of-contents" href="table-of-contents.html" media-type="application/xhtml+xml"/>
                {
                (: get all divs :)
                for $div in epub:frus-divs($text)
                return
                    <item id="{$div/@xml:id}" href="{$div/@xml:id}.html" media-type="application/xhtml+xml"/>
                }
                <item id="cover-image" href="images/cover.jpg" media-type="image/jpeg"/>
                <item id="css" href="stylesheet.css" media-type="text/css"/>
                {
                for $image in $text//tei:graphic[@url][not(ancestor::tei:titlePage)]
                return
                    <item id="{$image/@url}" href="images/{$image/@url}.png" media-type="image/png"/>
                ,
                if ($text//tei:cell[@role='brace']) then
                    for $brace-png in ('brace-open.png', 'brace-close.png')
                    return
                        <item id="{$brace-png}" href="images/{$brace-png}" media-type="image/png"/>
                else ()
                }
            </manifest>
            <spine toc="ncx">
                <itemref idref="cover" linear="no"/>
                <itemref idref="title"/>
                <itemref idref="about-epub"/>
                <itemref idref="table-of-contents"/>
                {
                (: get just divs for TOC :)
                for $div in epub:frus-divs($text)
                return
                    <itemref idref="{$div/@xml:id}"/>
                }
            </spine>
            <guide>
                <reference href="cover.html" type="cover" title="Cover"/>
                <reference href="about-epub.html" type="preface" title="About the Electronic Edition"/>
                <!-- TODO title.html omitted here - not sure if there's an applicable @type? -->
                <reference href="table-of-contents.html" type="toc" title="Table of Contents"/>
                <reference href="preface.html" type="preface" title="Preface"/>
                {
                (: first text div :)
                let $first-text-div := $text/tei:body//tei:div[tei:div/@xml:id and not(tei:div/tei:div/@xml:id)][1]
                let $id := $first-text-div/@xml:id
                let $title := $first-text-div/tei:head
                return
                    <reference href="{$id}.html" type="text" title="{$title}"/>
                }
                {
                (: index div :)
                if ($text/id('index')) then
                    <reference href="index.html" type="index" title="Index"/>
                else
                    ()
                }
            </guide>
        </package>
    return
        <entry name="OEBPS/content.opf" type="xml">{$content-opf}</entry>
};

(:~
    Helper function, contains the basic XHTML shell used by all XHTML files in the EPUB package.

    @param $title the page's title
    @param $body the body content
    @return the serialized XHTML element
:)
declare function epub:assemble-xhtml($title, $body) {
    let $xhtml :=
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>{$title}</title>
                <meta http-equiv="content-Type" content="text/html; charset=utf-8"/>
                <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
            </head>
            <body>
                {$body}
            </body>
        </html>
    return
        epub:serialize($xhtml)
};

declare function epub:serialize($xhtml) {
    let $serialization-parameters :=
        <output:serialization-parameters>
            <output:indent>no</output:indent>
        </output:serialization-parameters>
    return
        normalize-space(serialize($xhtml, $serialization-parameters))
};

(:~
    Helper function, creates the OEBPS/cover.html file.

    @param $title the page's title
    @return the entry for the OEBPS/cover.html file
:)
declare function epub:cover-xhtml-entry($title) {
    let $body :=
        <div xmlns="http://www.w3.org/1999/xhtml">
            <img src="images/cover.jpg" alt="{$title}" id="cover-image"/>
        </div>
    let $cover-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/cover.html" type="xml">{$cover-xhtml}</entry>
};

(:~
    Helper function, creates the OEBPS/title.html file.

    @param $volume the volume's ID
    @return the entry for the OEBPS/cover.html file
:)
declare function epub:title-xhtml-entry($volume-id) {
    let $volume := collection('/db/apps/frus/bibiliography')/volume[@id eq $volume-id]
    let $editor-roles-to-display := ('primary', 'general')
    let $editors := $volume/editor[@role = $editor-roles-to-display and . ne '']
    let $published-year := $volume/published-year/string()
    let $body :=
        <div xmlns="http://www.w3.org/1999/xhtml" id="title">
            <h3>{concat(frus:volume-title($volume-id, 'series'), ', ', frus:volume-title($volume-id, 'sub-series'))}</h3>
            <hr/>
            <h3>{frus:volume-title($volume-id, 'volume-number')}</h3>
            <h1>{frus:volume-title($volume-id, 'volume')}</h1>
            {
            if ($editors) then
                <dl>
                    {
                    for $role in frus:editor-roles()[. = $editors/@role]
                    let $editors-in-role := $editors[@role = $role]
                    let $label :=
                        if (count($editors-in-role) gt 1) then
                            frus:editor-role-to-label($role, 'plural')
                        else
                            frus:editor-role-to-label($role, 'singular')
                    return
                        (
                        <dt>{$label}:</dt>
                        ,
                        for $ed in $editors-in-role
                        return
                            <dd>{$ed/string()}</dd>
                        )
                    }
                </dl>
            else ()
            }
            <hr/>
            <p>
                United States Government Printing Office <br/>
                Washington <br/>
                {$published-year}
            </p>
            <p>
                U.S. Department of State <br/>
                Office of the Historian <br/>
                Bureau of Public Affairs
            </p>
            <hr/>
            <p>
                This ebook was generated on {format-date(current-date(), "[MNn] [D1], [Y0001]")}.<br/>
                Please visit the Office of the Historian <a href="http://history.state.gov/historicaldocuments/ebooks">ebooks web page</a> to access updates.
            </p>
        </div>
    let $title := 'Title page'
    let $title-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/title.html" type="xml">{$title-xhtml}</entry>
};

(:~
    Helper function, creates the OEBPS/about.html file.

    @param $title the page's title
    @return the entry for the OEBPS/about.html file
:)
declare function epub:about-xhtml-entry() {
    let $body := epub:process-xhtml(doc('/db/apps/release/resources/boilerplate/frus-about.xml'))
    let $title := 'About the Electronic Edition'
    let $cover-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/about-epub.html" type="xml">{$cover-xhtml}</entry>
};

(: a typeswitch routine to process dynamic content such as dates, e.g. <span class="ho:generate-month-year"/> returns "May 2012" :)
declare function epub:process-xhtml($node) {
    typeswitch($node)
        case text() return $node
        case element(xhtml:span) return
            if ($node/@class eq 'ho:generate-month-year') then
                format-date(current-date(), "[MNn] [Y0001]")
            else
                element { node-name($node) } { epub:process-xhtml-recurse($node) }
        case element() return element { node-name($node) } { $node/@*, epub:process-xhtml-recurse($node) }
        default return epub:process-xhtml-recurse($node)
};

(: helper for epub:process-xhtml :)
declare function epub:process-xhtml-recurse($node) {
    for $child in $node/node()
    return
        epub:process-xhtml($child)
};

(:~
    Helper function, creates the OEBPS/table-of-contents.html file.

    @param $title the page's title
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the entry for the OEBPS/table-of-contents.html file
:)
declare function epub:table-of-contents-xhtml-entry($title, $text, $suppress-documents, $options) {
    let $body :=
        <div xmlns="http://www.w3.org/1999/xhtml" id="table-of-contents">
            <h2>Contents</h2>
            {
            if ($options = 'mobi') then
                epub:frus-toc-to-li($text, $suppress-documents, $options)
            else
               <ul>{
                   (: Just get top level divs :)
                   epub:frus-toc-to-li($text, $suppress-documents, $options)
               }</ul>
            }
        </div>
    let $table-of-contents-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/table-of-contents.html" type="xml">{$table-of-contents-xhtml}</entry>
};

(:~
    Helper function, creates the XHTML files for the body of the EPUB.

    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the serialized XHTML page, wrapped in an entry element
:)
declare function epub:body-xhtml-entries($text, $options) {
    let $divs := epub:frus-divs($text)
    let $div-count := count($divs)
    (: TODO only log at discrete points, like every 5% or 10% :)
    for $div at $n in $divs
    let $log :=
        if ($div/@type='document') then () else console:log(concat('generating body-xhtml-entry for ', $div/@xml:id))
        (:console:log(concat('generating body-xhtml-entry for ', $div/@xml:id)):)
    let $title := frus:head-sans-note($div)
    let $body := epub:process-div($div, $title, $options)
    let $body-xhtml:= epub:assemble-xhtml($title, $body)
    (: previously we cached/stashed $body-xhtml and then included it in the zip via 
        <entry type="uri"> - as an attempt to "work around likely zip- and memory-related crashes" 
        but that no longer works: :)
    (:
    let $vol-id := substring-before(util:document-name($div), '.xml')
    let $xhtml-cache := concat($epub:cache-collection, '/', $vol-id, '/xhtml', if ($options = 'mobi') then '-mobi' else '-epub')
    let $check-collection :=
        if (xmldb:collection-available($xhtml-cache)) then
            ()
        else
            (
            xmldb:create-collection($epub:cache-collection, $vol-id),
            xmldb:create-collection(concat($epub:cache-collection, '/', $vol-id), concat('/xhtml', if ($options = 'mobi') then '-mobi' else '-epub'))
            )
    let $store := xmldb:store($xhtml-cache, concat($div/@xml:id, '.txt'), $body-xhtml)
    :)
    return
        <entry name="{concat('OEBPS/', $div/@xml:id, '.html')}" type="xml">{$body-xhtml}</entry>
};

declare function epub:process-div($div as element(tei:div), $title, $options) {
    let $parameters :=
        <parameters xmlns="">
            <param name="abs-site-uri" value="historicaldocuments/"/>
            <param name="relativeimagepath" value="images/"/>
            {
            if ($options = 'mobi') then <param name="ebook-format" value="mobi"/>
            else ()
            }
        </parameters>
    return
        (: just render documents, sections :)
        if ($div/@type = ('document', 'section')) then
            render:render($div, $parameters)
        else
            let $child-documents-to-show := $div/tei:div[@type='document']
            let $has-inner-sections := $div/tei:div[@type != 'document']
            let $notes := $div/tei:head/tei:note
            return
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <h1>{render:head($div/tei:head, $parameters)}</h1>
                    {
                    (: display any footnotes hung on the chapter heading, e.g., frus1952-54v08/comp3 :)
                    if ($notes) then
                        for $note at $incr in $notes
                        let $incr := if ($note/preceding::tei:note[@n = '0']) then $incr - 1 else $incr
                        return
                            <p>
                                <a href="{concat('#', $div/@xml:id, 'fnref', $incr)}" id="{concat($div/@xml:id, 'fn', $incr)}" class="footnote" style="display: inline">
                                    <sup>
                                        {($note/@n/string(), '*')[1]}
                                    </sup>
                                </a><span>&#160;</span>{render:recurse($note, $parameters)}
                            </p>
                    else ()
                    ,
                    (: for example of chapter div without no documents but a child paragraph, see frus1952-54v08/comp3
                        for an example of a subchapter div with a table, see frus1945Malta/ch8subch44 :)
                    let $child-nodes := $div/node()
                    let $first-head := index-of($child-nodes, $div/tei:head[1])
                    let $first-div := if ($div/tei:div) then index-of($child-nodes, $div/tei:div[1]) else ()
                    let $nodes-to-render :=
                        if ($first-div) then
                            subsequence($child-nodes, $first-head + 1, $first-div - $first-head - 1)
                        else
                            subsequence($child-nodes, $first-head + 1)
                    let $footnotes :=
                        for $note at $incr in $nodes-to-render//tei:note
                        let $incr := if ($div/tei:note[@n = '0']) then (count($notes) + $incr - 1) else (count($notes) + $incr)
                        return
                            <p>
                                <a href="{concat('#', $div/@xml:id, 'fnref', $incr)}" id="{concat($div/@xml:id, 'fn', $incr)}" class="footnote" style="display: inline">
                                    <sup>
                                        {($note/@n/string(), '*')[1]}
                                    </sup>
                                </a><span>&#160;</span>{render:recurse($note, $parameters)}
                            </p>
                    return
                        (
                            render:main($nodes-to-render, ())
                            ,
                            $footnotes
                        )
                    ,
                    for $document in $child-documents-to-show
                    let $docnumber := frus:document-number($document)
                    let $docid := frus:document-id($document)
                    let $doctitle := frus:document-head-sans-number($document)
                    let $docsource := frus:source-note($document)/string()
                    let $docdateline := string-join(render:main(frus:dateline($document), <parameters xmlns=""><param name="strip-line-breaks" value="true"/></parameters>), '')
                    let $docsummary := $document//tei:note[@type='summary']/string()
                    return
                        (
                        <hr class="list"/>,
                        <h4><a href="{concat($docid, '.html')}">{if (not(starts-with($document/tei:head, concat($document/@n, '.')))) then concat('[', $docnumber, ']') else concat($docnumber, '. '), $doctitle}</a></h4>,
                        <p class="dateline">{$docdateline}</p>,
                        if (exists($docsummary)) then <p>{$docsummary}</p> else (),
                        <p class="sourcenote">{$docsource}</p>
                        )
                    ,
                    if ($has-inner-sections) then
                        (
                        <hr/>
                        ,
                        <div>
                            <h2>Contents</h2>
                            <ul>{
                                epub:frus-toc-to-li($div/tei:div[not(@type='document')], true(), $options)
                            }</ul>
                        </div>
                        )
                    else
                        ()
                    }
                </div>
};

(:~
    Helper function, creates the CSS entry for the EPUB.

    @param $db-path-to-css the db path to the required static resources (cover.jpg, stylesheet.css)
    @return the CSS entry
:)
declare function epub:stylesheet-entry($db-path-to-css) {
    <entry name="OEBPS/stylesheet.css" type="binary">{util:binary-doc(concat($db-path-to-css, '/css/epub.css'))}</entry>
};


(:~
    Helper function, creates the OEBPS/toc.ncx file.

    @param $urn the EPUB's urn
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the NCX element's entry
:)
declare function epub:toc-ncx-entry($urn, $title, $text) {
    let $toc-ncx :=
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="{$urn}"/>
                <meta name="dtb:depth" content="2"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle>
                <text>{$title}</text>
            </docTitle>
            <navMap>
                <navPoint id="navpoint-cover" playOrder="1">
                    <navLabel>
                        <text>Cover</text>
                    </navLabel>
                    <content src="cover.html"/>
                </navPoint>
                <navPoint id="navpoint-title" playOrder="2">
                    <navLabel>
                        <text>Title</text>
                    </navLabel>
                    <content src="title.html"/>
                </navPoint>
                <navPoint id="navpoint-about-epub" playOrder="3">
                    <navLabel>
                        <text>About the Electronic Edition</text>
                    </navLabel>
                    <content src="about-epub.html"/>
                </navPoint>
                <navPoint id="navpoint-table-of-contents" playOrder="4">
                    <navLabel>
                        <text>Table of Contents</text>
                    </navLabel>
                    <content src="table-of-contents.html"/>
                </navPoint>
                {
                epub:frus-toc-to-ncx($text, 5)
                }
            </navMap>
        </ncx>
    return
        <entry name="OEBPS/toc.ncx" type="xml">{$toc-ncx}</entry>
};

declare function epub:frus-toc-to-ncx($node, $navpoint-start as xs:integer) {
    typeswitch($node)
        case element(tei:div) return epub:frus-div-to-ncx($node, $navpoint-start)
        default return epub:recurse-ncx($node, $navpoint-start)
};

declare function epub:recurse-ncx($node, $navpoint-start) {
    for $child in $node/node()
    return epub:frus-toc-to-ncx($child, $navpoint-start)
};

declare function epub:frus-div-to-ncx($div as element(tei:div), $navpoint-start as xs:integer) {
    let $id := $div/@xml:id
    let $index := count($div/preceding::tei:div[@xml:id and not(@xml:id = $epub:frus-div-xmlids-to-suppress)]) + count($div/ancestor::tei:div[@xml:id and not(@xml:id = $epub:frus-div-xmlids-to-suppress)])
    return
        (: just pass through non-@xml:id divs :)
        if (not($id)) then
            epub:recurse-ncx($div, $navpoint-start)
        (: supress original print TOC, since we generate an ePub-specific one :)
        else if ($id = $epub:frus-div-xmlids-to-suppress) then
            ()
        (: show all divs with @xml:id :)
        else
            <navPoint id="navpoint-{$id}" playOrder="{$navpoint-start + $index}" xmlns="http://www.daisy.org/z3986/2005/ncx/">
                <navLabel>
                    <text>{
                        (: show a bracketed document number for volumes that don't use document numbers :)
                        if ($div/@type = 'document' and not(starts-with($div/tei:head, concat($div/@n, '.')) or starts-with($div/tei:head, concat('No. ', $div/@n)))) then concat('[', $div/@n, ']') else (),
                        normalize-space(frus:head-sans-note($div))}</text>
                </navLabel>
                <content src="{$id}.html"/>
                { epub:recurse-ncx($div, $navpoint-start) }
            </navPoint>
};

declare function epub:frus-toc-to-li($node, $suppress-documents as xs:boolean, $options) {
    typeswitch($node)
        case element(tei:div) return epub:frus-div-to-li($node, $suppress-documents, $options)
        default return epub:recurse-li($node, $suppress-documents, $options)
};

declare function epub:recurse-li($node, $suppress-documents, $options) {
    for $child in $node/node()
    return epub:frus-toc-to-li($child, $suppress-documents, $options)
};

declare function epub:frus-div-to-li($div as element(tei:div), $suppress-documents as xs:boolean, $options) {
    let $id := $div/@xml:id
    return
        (: just pass through non-@xml:id divs :)
        if (not($id)) then
            epub:recurse-li($div, $suppress-documents, $options)
        (: supress original print TOC, since we generate an ePub-specific one :)
        else if ($id = $epub:frus-div-xmlids-to-suppress) then
            ()
        else if ($div/@type = ('document', 'introduction')) then
            if ($suppress-documents) then ()
            else
                if ($options = 'mobi') then
                    <blockquote xmlns="http://www.w3.org/1999/xhtml">
                        <a href="{concat($div/@xml:id, '.html')}">{
                            normalize-space(frus:head-sans-note($div))
                        }</a>
                    </blockquote>
                else
                    <li xmlns="http://www.w3.org/1999/xhtml">
                        <a href="{concat($div/@xml:id, '.html')}">{
                            normalize-space(frus:head-sans-note($div))
                        }</a>
                    </li>
        (: show all divs with @xml:id :)
        else
            if ($options = 'mobi') then
                <blockquote xmlns="http://www.w3.org/1999/xhtml">
                    <a href="{concat($div/@xml:id, '.html')}">{
                        normalize-space(frus:head-sans-note($div))
                    }</a>
                    {
                    if ($div[tei:div/@type eq 'document']) then
                        if ($suppress-documents) then
                            concat(' (Documents ', $div/tei:div[@n][1]/@n, '-', $div/tei:div[@n][last()]/@n, ')')
                        else ()
                    else
                        ()
                    ,
                    if ($div//tei:div[@xml:id and not(@type = ('document', 'introduction'))] or not($suppress-documents)) then
                        epub:recurse-li($div, $suppress-documents, $options)
                    else ()
                    }
                </blockquote>
            else
                <li xmlns="http://www.w3.org/1999/xhtml">
                    <a href="{concat($div/@xml:id, '.html')}">{
                        normalize-space(frus:head-sans-note($div))
                    }</a>
                    {
                    if ($div[tei:div/@type eq 'document']) then
                        if ($suppress-documents) then
                            concat(' (Documents ', $div/tei:div[@n][1]/@n, '-', $div/tei:div[@n][last()]/@n, ')')
                        else ()
                    else
                        ()
                    ,
                    if ($div//tei:div[@xml:id and not(@type = ('document', 'introduction'))] or not($suppress-documents)) then
                        <ul>{ epub:recurse-li($div, $suppress-documents, $options) }</ul>
                    else ()
                    }
                </li>
};

(:~
    Helper function, creates the cover image entry for the EPUB.

    @param $cover-uri the db path to the file to be used for the cover
    @return the cover entry
:)
declare function epub:cover-entry($cover-uri) {
    <entry name="OEBPS/images/cover.jpg" type="binary">{util:binary-doc($cover-uri)}</entry>
};

declare function epub:graphic-entries($text) {
    let $vol-id := substring-before(util:document-name($text), '.xml')
    let $image-uris := epub:cache-all-images($text)
    for $image-uri in $image-uris
    let $filename := substring-after($image-uri, 'images/')
    return
        <entry name="{concat('OEBPS/images/', $filename)}" type="binary">{util:binary-doc($image-uri)}</entry>
};

declare function epub:cache-image($href, $target-collection, $filename) {
    let $request := <hc:request href="{$href}" method="head" http-version="1.1"/>
    let $response := hc:send-request($request)
    return
        if ($response/@status eq '200') then
            let $request := <hc:request href="{$href}" method="get" http-version="1.1"/>
            let $response := hc:send-request($request)
            let $response-body := $response[2]
            let $store := xmldb:store($target-collection, xmldb:encode($filename), $response-body, 'image/png')
            return
                concat($target-collection, '/', $filename)
        else
            error(xs:QName('epub-error'), concat('Unable to fetch image ', $href, ' for volume ', $filename, ' from S3'))
};

declare function epub:cache-all-images($text) {
    let $vol-id := substring-before(util:document-name($text), '.xml')
    let $graphics :=
        (
        for $graphic-basename in distinct-values($text/(tei:body | tei:back)//tei:graphic/@url)
        return
            <graphic file="{concat($graphic-basename, '.png')}" cache-path="{$vol-id}/images" s3-path="{concat('frus/', $vol-id)}"/>
        ,
        let $has-braces := $text//tei:cell[@role = 'brace']
        return
            if ($has-braces) then
                for $brace-image in ('brace-open', 'brace-close')
                return
                    <graphic file="{concat($brace-image, '.png')}" cache-path="{$vol-id}/images" s3-path="images"/>
            else
                ()
        )
    return
        if (exists($graphics)) then
            let $ensure-collections-exist :=
                (
                xmldb:create-collection($epub:cache-collection, 'images'),
                xmldb:create-collection($epub:cache-collection, $vol-id),
                xmldb:create-collection(concat($epub:cache-collection, '/', $vol-id), 'images')
                )
            for $graphic in $graphics
            let $graphic-binary-uri :=
                if (util:binary-doc-available(concat($epub:cache-collection, '/', $graphic/@cache-path, '/', $graphic/@file))) then
                    concat($graphic/@cache-path, '/', $graphic/@file)
                else
                    let $uri := concat('https://s3.amazonaws.com/static.history.state.gov/', $graphic/@s3-path, '/', encode-for-uri($graphic/@file))
                    return
                        epub:cache-image($uri, concat($epub:cache-collection, '/', $graphic/@cache-path), $graphic/@file)
            let $path-to-cached-image := concat($epub:cache-collection, '/', $graphic-binary-uri)
            return
                $path-to-cached-image
        else ()
};

declare function epub:clear-cache($vol-id) {
    xmldb:remove(concat($epub:cache-collection, '/', $vol-id))
};

declare function epub:clear-image-cache($vol-id) {
    xmldb:remove(concat($epub:cache-collection, '/', $vol-id, '/images'))
};

declare function epub:clear-ncx-cache($vol-id) {
    xmldb:remove(concat($epub:cache-collection, '/', $vol-id, '/ncx'))
};

declare function epub:clear-xhtml-cache($vol-id) {
    xmldb:remove(concat($epub:cache-collection, '/', $vol-id, '/xhtml'))
};

declare function epub:cache-ncx-collection($vol-id) {
    concat($epub:cache-collection, '/', $vol-id, '/ncx')
};

declare function epub:cache-ncx($vol-id) {
    let $ncx := epub:toc-ncx-entry($vol-id, $vol-id, frus:volume($vol-id))
    let $check-collection :=
        if (xmldb:collection-available(epub:cache-ncx-collection($vol-id))) then
            ()
        else
            (
            xmldb:create-collection($epub:cache-collection, $vol-id),
            xmldb:create-collection(concat($epub:cache-collection, '/', $vol-id), 'ncx')
            )
    let $store := xmldb:store(epub:cache-ncx-collection($vol-id), concat($vol-id, '.ncx'), $ncx)
    return ()
};

declare function epub:get-ncx($vol-id) {
    let $vol := frus:volume($vol-id)
    let $cache-collection := epub:cache-ncx-collection($vol-id)
    let $cache-filename := concat($vol-id, '.ncx')
    let $cache-doc := concat($cache-collection, '/', $cache-filename)
    let $exists-cache := doc-available($cache-doc)
    return
        if ($exists-cache and
                xmldb:last-modified(util:collection-name($vol), util:document-name($vol))
                le
                xmldb:last-modified($cache-collection, $cache-filename)
            ) then
            doc($cache-doc)
        else (
            epub:cache-ncx($vol-id),
            doc($cache-doc)
            )
};

declare function epub:get-current-navPoint-playOrder($ncx, $id) {
    xs:integer($ncx//ncx:navPoint[ncx:content/@src eq $id]/@playOrder)
};

declare function epub:get-previous-navPoint($ncx, $current-playOrder-value as xs:integer) {
    $ncx//ncx:navPoint[xs:integer(@playOrder) eq $current-playOrder-value - 1]
};

declare function epub:get-next-navPoint($ncx, $current-playOrder-value as xs:integer) {
    $ncx//ncx:navPoint[xs:integer(@playOrder) eq $current-playOrder-value + 1]
};
