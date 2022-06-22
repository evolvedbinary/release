xquery version "3.0";

module namespace epub3 = "http://history.state.gov/ns/xquery/epub3/epub";

import module namespace pm-config="http://www.tei-c.org/tei-simple/config" at "/db/apps/tei-publisher/modules/config.xqm";
import module namespace epub2 = "http://history.state.gov/ns/xquery/epub" at "epub.xql";
import module namespace epub = "http://exist-db.org/xquery/epub" at "/db/apps/tei-publisher/modules/lib/epub.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "/db/apps/tei-publisher/modules/navigation.xql";
import module namespace compression = "http://exist-db.org/xquery/compression";
import module namespace frus="http://history.state.gov/ns/xquery/frus" at "frus.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "/db/apps/tei-publisher/modules/lib/util.xql";

import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace opf = "http://www.idpf.org/2007/opf";
declare namespace ncx = "http://www.daisy.org/z3986/2005/ncx/";

declare variable $epub3:cache-collection := '/db/apps/release/epub-cache';
declare variable $epub3:abs-site-uri := 'historicaldocuments/';

declare function local:generate-epub($id, $doc, $title, $creator, $text, $urn, $db-path-to-resources, $cover, $filename, $options) {
    (: $title                : volume (series, sub-series, volume-number) :)
    (: $creator              : Constant :)
    (: $text                 : /text node :)
    (: $urn                  : id+timestamp :)
    (: $db-path-to-resources : resources path (css, images, and about.xml) :)
    (: $cover                : get cover image path, if not found download it, if not found use default cover :)
    (: $filename             : output epub filename :)
    (: $options              : () :)

    let $default-config := $pm-config:epub-config($doc, ())
    let $config := map:merge((
        $default-config,
        map {
            "options": $options,
            (:"fonts": (),:)
            "metadata": map:merge(
                ($default-config?metadata,
                map {
                    "id": $id,
                    "title": $title,
                    "creator": $creator,
                    "urn": $urn
                })
            )
        }
    ))
    let $odd := head($pm-config:default-odd)
    let $oddName := replace($odd, "^([^/\.]+).*$", "$1")
    let $css-default := util:binary-to-string(util:binary-doc($pm-config:output-root || "/" || $oddName || ".css"))
    let $css-epub := util:binary-to-string(util:binary-doc("/db/apps/release/resources/css/epub.css"))
    let $css-epub3 := util:binary-to-string(util:binary-doc("/db/apps/release/resources/css/epub3.css"))
    let $css := concat($css-default, $css-epub, $css-epub3)
    let $updated := local:update-document($config, $doc)/node()
    let $stored := xmldb:store($epub3:cache-collection, concat('/', $id, ".xml"), $updated)
    let $stored := doc(concat($epub3:cache-collection, '/', $id, ".xml"))
    return
        let $raw-epub := epub:generate-epub($config, $stored/*, $css, $id)
        let $epub := document { ($raw-epub) }
        return local:post-process-document($epub/node())
};

declare function local:frus-toc-to-li($node, $suppress-documents as xs:boolean, $options) {
    typeswitch($node)
        case element(tei:div) return local:frus-div-to-li($node, $suppress-documents, $options)
        default return local:recurse-li($node, $suppress-documents, $options)
};

declare function local:recurse-li($node, $suppress-documents, $options) {
    for $child in $node/node()
    return local:frus-toc-to-li($child, $suppress-documents, $options)
};

declare function local:frus-div-to-li($div as element(tei:div), $suppress-documents as xs:boolean, $options) {
    let $id := $div/@xml:id
    return
        if (not($id)) then
            local:recurse-li($div, $suppress-documents, $options)
        else if ($id = $epub2:frus-div-xmlids-to-suppress) then
            ()
        else if ($div/@type = ('document', 'introduction')) then
            if ($suppress-documents) then
                ()
            else
                <tei:item>
                    <tei:ref target="#{$div/@xml:id}">{
                        normalize-space(frus:head-sans-note($div))
                    }</tei:ref>
                </tei:item>
        else
            <tei:item>
                <tei:ref target="#{$div/@xml:id}">{
                    normalize-space(frus:head-sans-note($div))
                }</tei:ref>
                {
                if ($div[tei:div/@type eq 'document']) then
                    if ($suppress-documents) then
                        concat(' (Documents ', $div/tei:div[@n][1]/@n, '-', $div/tei:div[@n][last()]/@n, ')')
                    else ()
                else
                    ()
                ,
                if ($div//tei:div[@xml:id][not(@type = ('document', 'introduction'))] or not($suppress-documents)) then
                    <tei:list>{ local:recurse-li($div, $suppress-documents, $options) }</tei:list>
                else ()
                }
            </tei:item>
};

declare function local:cache-graphic-image($node) {
    let $graphic-basename := $node/@url
    return
        if (contains($graphic-basename, '.')) then
            $graphic-basename
        else
            let $vol-id := substring-before(util:document-name($node), '.xml')
            let $file := concat($graphic-basename, '.png')
            let $rel-images-path := "images"
            let $s3-path := concat('frus/', $vol-id)
            let $ensure-collections-exist := (
                xmldb:create-collection($epub3:cache-collection, $rel-images-path)
            )
            let $images-path := concat($epub3:cache-collection, '/', $rel-images-path)
            let $rel-file-path := concat($rel-images-path, '/', $file)
            let $file-path := concat($images-path, '/', $file)
            let $graphic-binary-uri :=
                if (util:binary-doc-available($file-path)) then
                    $file-path
                else
                    let $uri := concat('https://static.history.state.gov/', $s3-path, '/', encode-for-uri($file))
                    return
                        local:cache-image($uri, $images-path, $file)
            return
                $rel-file-path
};

declare function local:cache-image($href, $target-collection, $filename) {
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

declare function local:generate-target($id, $node) {
    let $node := root($node)//node()[@xml:id=$id]
    let $parent := if ($node) then
        typeswitch ($node) 
            case element(tei:div)return false()
            default return $node/ancestor::tei:div[1]
        else ()
    return if ($node) then
        concat(
            epub:generate-id(if ($parent) then $parent else $node), '.xhtml',
            if ($parent) then concat('#', typeswitch ($node) 
                case element(tei:note) return 'fn'
                default return '',
            epub:generate-id($node)) else ()
        ) else ''
};

declare function local:pb-to-document-links($vol as document-node(), $pb-id as xs:string) {
    local:pb-range-to-document-links($vol, $pb-id, $pb-id)
};

declare function local:pb-range-to-document-links($vol as document-node(), $pb1-id as xs:string, $pb2-id as xs:string) {
    let $pb1 := $vol/id($pb1-id)
    let $pb2 := $vol/id($pb2-id)
    let $range-start := $pb1
    let $range-end := subsequence($pb2/following::tei:pb, 1, 1)
    let $divs := $vol//tei:div[@type=('document', 'section') and @xml:id]
    let $divs-within-range := $divs[. >> $range-start and . << $range-end]/@xml:id
    let $ancestor-document := subsequence($range-start/ancestor::tei:div[@type=('document', 'section') and @xml:id], 1, 1)/@xml:id
    let $doc-ids := distinct-values(($ancestor-document, $divs-within-range)[. ne ''])
    let $doc-ids := if (empty($doc-ids)) then ($pb1/ancestor::tei:div[@xml:id][1]/@xml:id, $pb1/following::tei:div[@xml:id][1]/@xml:id)[1] else $doc-ids
    let $docs-in-frag := for $doc-id in $doc-ids return $vol/id($doc-id)
    let $link :=
        <tei:s rend="small">[<tei:s rend="italic">{
            let $docs-count := count($docs-in-frag)
            return
                if ($docs-count = 0) then
                    ()
                else if ($docs-count = 1) then
                    (
                    if ($pb1 = $pb2) then
                        concat('Pg. ', $pb1/@n, ' is part of ')
                    else
                        concat('Pgs. ', $pb1/@n, '–', $pb2/@n, ' are part of ')
                    ,
                    <tei:ref target="{local:generate-target($docs-in-frag/@xml:id, $docs-in-frag)}">{
                        for $doc in $docs-in-frag
                        return
                            if ($doc/@type='document') then
                                concat('Doc. ', $doc/@n)
                            else
                                frus:head-sans-note($doc)
                    }</tei:ref>
                    )
                else
                    (
                    if ($pb1-id = $pb2-id) then
                        concat('Pg. ', $pb1/@n, ' includes portions of ')
                    else
                        concat('Pgs. ', $pb1/@n, '–', $pb2/@n, ' include portions of ')
                    ,
                    for $doc at $count in $docs-in-frag
                    return
                        (
                            <tei:ref target="{local:generate-target($doc/@xml:id, $doc)}">{if ($doc/@n ne '') then concat('Doc. ', $doc/@n) else frus:head-sans-note($doc)}</tei:ref>,
                            if ($count lt $docs-count - 1 and $docs-count gt 2) then
                                ', '
                            else if ($count lt $docs-count) then
                                if ($docs-count = 2) then
                                    ' and '
                                else
                                    ', and '
                            else ()
                        )
                    )
        }</tei:s>]</tei:s>
    return
        $link
};

declare function local:remove-title($node, $title) {
    if (fn:deep-equal($node, $title)) then () else 
    typeswitch ($node)
        case text() return $node
        default return element {node-name($node)} {(
            $node/@*,
            for $child in $node/node()
                return local:remove-title($child, $title)
        )}
};

declare function local:update-content($nodes) {
    for $node in $nodes
        return typeswitch ($node)
            case text() return $node
            case element(opf:manifest)
                return element {node-name($node)} {(
                $node/@*,
                for $sub-node in $node/node()
                    return if ($sub-node[@id="title"] or $sub-node/preceding-sibling::*[1][@id="title"]) then () else $sub-node
                )}
            case element(opf:spine) return
                element {node-name($node)} {(
                    $node/@*,
                    for $sub-node in $node/node()
                        return if ($sub-node[@idref="title"] or $sub-node/preceding-sibling::*[1][@idref="title"]) then () else $sub-node
                )}
            default return element {node-name($node)} {(
                $node/@*,
                for $child in $node/node()
                    return local:update-content($child)
            )}
};

declare function local:update-nav($nodes) {
    for $node in $nodes
        return typeswitch ($node)
            case text() return $node
            case element(xhtml:li)
                return if(ends-with($node/xhtml:a/@href, '-generated-document')) then () else element {node-name($node)} {(
                    $node/@*,
                    local:update-nav($node/node())
                )}
            default return element {node-name($node)} {(
                $node/@*,
                for $child in $node/node()
                    return local:update-nav($child)
            )}
};

declare function local:update-toc($nodes) {
    for $node in $nodes
        return typeswitch ($node)
            case text() return $node
            case element(ncx:navMap) return
                element {node-name($node)} {(
                    $node/@*,
                    $node/node()[not(@id="navpoint-title")][not(./text()="Title")]
                )}
            default return element {node-name($node)} {(
                $node/@*,
                for $child in $node/node()
                    return local:update-toc($child)
            )}
};
declare function local:post-process-entry-contents($node) {
    typeswitch ($node)
        case text() return $node
        case element(xhtml:aside) return 
            element {node-name($node)} {
                $node/@*,
                for $child in $node/node()
                    return typeswitch ($child) 
                        case text() return $child
                        default return 
                            let $child := local:post-process-entry-contents($child)
                            let $class := concat($child/@class, ' ')
                            let $child := if (contains($class, 'bold ')) then
                                <strong>{$child}</strong>
                            else $child
                            let $child := if (contains($class, 'italic ')) then
                                <em>{$child}</em>
                            else $child
                            let $child := if (contains($class, 'underline ')) then
                                <u>{$child}</u>
                            else $child
                            return $child
            }
        case element(xhtml:a) return
            if (contains(concat($node/@class, ' '), 'tei-ref3 ')) then
                element {node-name($node)} {(
                    ($node/@* except $node/@href, attribute href {
                        $node/@href ! (
                            let $nodes :=
                                if (starts-with(., '#')) then
                                    if (starts-with(., '#in')) then
                                        (concat('index.xhtml', .))
                                    else if (matches(., '^#d\d+$')) then
                                        (substring-after(., '#'))
                                    else if (matches(., '^#d\d+fn\d+$')) then
                                        let $document-id := substring-after(substring-before(., 'fn'), '#')
                                        let $footnote-n := number(substring-after(., 'fn'))
                                        let $document := root($node)//xhtml:div[@id=$document-id]
                                        let $node-id := if ($document) then 
                                            $document/..//xhtml:aside[position()=$footnote-n]/@id
                                        else ()
                                            return ($document-id, $node-id, 'fn')
                                    else if (matches(., '^#d\d+.+$')) then
                                        (replace(., '^#(d\d+).+$', '$1'), substring-after(., '#'))
                                    else
                                        let $document := substring-after(., '#')
                                        return if (contains($document, '#')) then
                                            let $node := substring-after($document, '#')
                                            let $document := substring-before($document, '#')
                                            return ($document, $node, 'a#b')
                                        else
                                            ($document, (), 'doc')
                                    else
                                        ()
                            return
                                (:($nodes[3], ': ', $nodes[1], '/', $nodes[2], ' ::: ',:)
                                if ($nodes[1]) then
                                    let $document := root($node)//xhtml:div[@id=$nodes[1]]/ancestor::entry/@name
                                    let $document := if (starts-with($document, 'chapter-')) then
                                            concat('ch-', substring-after($document, 'chapter-'))
                                        else if (starts-with($document, 'compilation-')) then
                                            concat('comp-', substring-after($document, 'compilation-'))
                                        else if (starts-with($document, 'appendix-')) then
                                            concat('app', substring-after($document, 'appendix-'))
                                        else if (starts-with($document, 'conclusion')) then
                                            'conclusion'
                                        else if (starts-with($document, 'introduction')) then
                                            'introduction'
                                        else
                                            $document
                                    return if ($document) then
                                        let $node := $document/id($nodes[2])
                                        return concat(substring-after($document, 'OEBPS/'), if ($nodes[2]) then concat('#', $nodes[2]) else '')
                                    else
                                        if (contains($nodes[1], ('.xhtml', '::/'))) then
                                            $nodes[1]
                                        else
                                            .
                            else
                                .)
                                (:):)
                        }),
                    for $child-node in $node/node()
                        return local:post-process-entry-contents($child-node)
                )}
            else $node
        default return
            if (count($node/node()) > 0) then
                element {node-name($node)} {(
                    $node/@*,
                    for $child-node in $node/node()
                        return local:post-process-entry-contents($child-node)
                )}
            else
                $node
};
declare function local:post-process-document($entries) {
    let $result := for $entry in $entries
        let $type := data($entry/@type)
        return if ($type = ("text", "binary")) then
            $entry
        else
            let $entry := local:post-process-entry-contents($entry)
            let $ext := replace(data($entry/@name), "^.*\.([^.]*)", "$1")
            let $entry := if ($ext = ("xhtml")) then
                if ($entry[@name="OEBPS/nav.xhtml"]) then local:update-nav(($entry)) else
                if ($entry[@name="OEBPS/title.xhtml"]) then () else
                if ($entry[.//xhtml:body/xhtml:div/xhtml:p/text()="::delete::"][.//xhtml:head/xhtml:title/text()="--no title---"]) then
                    ()
                else if ($entry/xhtml:html/xhtml:body/node()[1]/@id = ('cover', 'table-of-contents', 'title')) then
                    local:remove-title($entry, $entry/xhtml:html/xhtml:body/node()[1]/node()[1])
                else
                    $entry
            else if ($ext = "opf") then
                local:update-content(($entry))
            else if ($ext = "ncx") then
                local:update-toc(($entry))
            else
                $entry
            return $entry
    return $result
};

declare function local:update-document($config, $doc) {
    let $root := $doc/node()
    return (document { element {node-name($root)} {(
        $root/@*,
        for $node in $root/*
            return typeswitch ($node)
                case element(tei:text) return <tei:text><tei:div><p>::delete::</p></tei:div>{local:update-text($config, $node)}</tei:text>
                default return $node
    )} })
};
declare function local:update-text($config, $text) {
    for $node in $text/node()
        return typeswitch ($node)
            case element(tei:front) return <front>{(
                local:cover-xhtml($config, $node),
                local:title-xhtml($config),
                (: for now, we don't need to update the contents of the about page
                   however we should recheck if its content changes in the future :)
                (:local:update-text-node($config, local:about-xhtml($config)),:)
                local:about-xhtml($config),
                local:toc-xhtml($config, $text, true()),
                for $sub-node in $node/tei:div[not(@xml:id = $epub2:frus-div-xmlids-to-suppress)]
                    return local:update-text-node($config, $sub-node, true())
            )}</front>
            default return (
                if (count($node/*) > 0) then
                    local:update-text-node($config, $node)
                else
                    $node
            )
};
declare function local:update-text-node($config, $node) {
    local:update-text-node($config, $node, false())
};
declare function local:update-text-node($config, $node, $skip-nesting) {
    typeswitch ($node)
        case text() return $node
        case element(tei:graphic) return element {node-name($node)} {(
            ($node/@*[not(name()="url")], attribute url { local:cache-graphic-image($node) }),
            $node/node()
        )}
        case element(tei:date) return element {node-name($node)} {(
            $node/@*[not(name()="when")],
            $node/node()
        )}
        case element(tei:head) return
            let $attr := if ($node/parent::tei:div[./*[1] = $node][./parent::tei:front]) then
                attribute rend { "front-title" }
            else
                ()
            return element {node-name($node)} {(
                ($node/@*, $attr),
                for $child-node in $node/node()
                    return local:update-text-node($config, $child-node)
            )}
        case element(xhtml:span) return
            if ($node/@class eq 'ho:generate-month-year') then
                format-date(current-date(), "[MNn] [Y0001]")
            else
                element {node-name($node)} {(
                    $node/@*,
                    for $child-node in $node/node()
                        return local:update-text-node($config, $child-node)
                )}
        case element(tei:note) return
            if ($node[@rend='inline']) then
                <tei:p>{(
                    $node/@*[not(name()="when")],
                    for $child-node in $node/node()
                        return local:update-text-node($config, $child-node)
                )}</tei:p>
            else if ($node/@rend and empty(root($node)//*[xml:id=@rend])) then
                ()
            else
                element {node-name($node)} {(
                    $node/@*[not(name()="when")],
                    for $child-node in $node/node()
                        return local:update-text-node($config, $child-node)
                )}
        case element(frus:attachment) return
            <tei:div att="frus">{(
                if ($node/@xml:id) then <anchor xml:id="{$node/@xml:id}" /> else (),                
                $node/@*,
                for $child-node in $node/node()
                    return local:update-text-node($config, $child-node)
            )}</tei:div>
        case element(tei:ref) return
            let $target := $node/@target
            let $result := 
                if (starts-with($target, '#')) then
                    if (starts-with($target, '#pg')) then
                        if (
                            let $first-node := $node/preceding-sibling::node()[1]
                            let $second-node := $node/preceding-sibling::node()[2]
                            return
                                $first-node eq '–' and $second-node instance of element(tei:ref) and $second-node[starts-with(@target, '#pg')]
                            ) then (
                            $target,
                            local:pb-range-to-document-links(
                                root($node),
                                substring-after($node/preceding-sibling::tei:ref[1]/@target, '#'),
                                substring-after($target, '#')
                            )
                        ) else if (subsequence($node/following-sibling::node(), 1, 1) eq '–' and subsequence($node/following-sibling::node(), 2, 1)/./self::tei:ref[starts-with(@target, '#pg')]) then
                            ($target, <tei:p>render:recurse($node, $options)</tei:p>)
                        else (
                            ($target, (' ', local:pb-to-document-links(root($node), substring-after($target, '#'))))
                        )
                    else
                        ($target)
                else if (contains($target, '#') and contains($target, 'fn')) then
                    (concat('http://history.state.gov/', $epub3:abs-site-uri, substring-before($target, '#'), '/',
                        concat(substring-before(substring-after($target, '#'), 'fn'), '#fn',
                        substring-after($target, 'fn')), (:$persistent-view:) false()))
                else if (contains($target, '#')) then
                    (concat('http://history.state.gov/', $epub3:abs-site-uri, substring-before($target, '#'), '/', substring-after($target, '#')))
                else if (starts-with($target, 'frus')) then
                    (concat('http://history.state.gov/', $epub3:abs-site-uri, $target))
                else
                    ($target)
            return
                (
                    element { node-name($node) } {
                        $node/@*[local-name() != 'target'],
                        attribute target { $result[1] },
                        (:attribute target { concat($target, ' :: ', $result[1]) },:)
                        for $child-node in $node/node()
                            return local:update-text-node($config, $child-node)
                    },
                    $result[2]
                )
        case element(tei:item) return element {node-name($node)} {(
            $node/@*, if ($node/parent::tei:list/*[1][local-name()!="head"] and $node/parent::tei:list/@type = ('participants', 'subject', 'from', 'references', 'to') ) then
                attribute rend { "subjectallcaps" }
            else (),
                for $child-node in $node/node()
                    return local:update-text-node($config, $child-node)
            )}
        case element(tei:list) return
            let $list-rend := if ($node/@type) then switch ($node/@type)
                case 'index' return "index"
                case 'indexentry' return "indexentry"
                case 'ordered' return "customorder"
                case 'bulleted' return "bulleted"
                default return if ($node/@type = ('participants', 'subject', 'from', 'references', 'to')) then "subject" else ()
            else ()
            let $item-rend := if (($node/@type, $node/ancestor::tei:list/@type) = ('participants', 'subject', 'from', 'references', 'to')) then "subjectallcaps" else ()
            let $list-attr := (
                $node/@*[local-name() != 'rend'][local-name() != 'type'], 
                attribute rend { if ($list-rend) then ($node/@rend, $list-rend) else $node/@rend }
            )
            let $item-attr := if ($item-rend) then (attribute rend { $item-rend }) else ()
            return if ($node/*[1][local-name()="head"]) then element {node-name($node)} {(
                $list-attr, $node/@type,
                <tei:item>{$item-attr[local-name() != 'rend'], attribute rend { ($item-attr[local-name() = 'rend'], "sub-list") },
                    $node/tei:head/node()}</tei:item>,
                    for $child-node in $node/node()[./tei:list] return
                        local:update-text-node($config, $child-node)
                    ,
                    <tei:item>
                    <tei:list>{$list-attr[local-name() != 'rend'], attribute rend { ($list-attr[local-name() = 'rend'], "sub-list") }}
                        {for $child-node in $node/node()[not(local-name()="head")][not(./tei:list)] return
                            local:update-text-node($config, $child-node)
                        }
                    </tei:list>
                </tei:item>
            )}
            else element {node-name($node)} {(
                $node/@*,
                for $child-node in $node/node()
                    return local:update-text-node($config, $child-node)
            )}
        case element(tei:div) return
            if ($skip-nesting) then
                element {node-name($node)} {(
                    $node/@*,
                    for $child in $node/node()
                        return local:update-text-node($config, $child)
                )}
            else if ($node/@type = ("document")) then
                let $head := $node/tei:head
                let $is-document := starts-with($head, concat($node/@n, '.')) or starts-with($head, concat('No. ', $node/@n))
                return element {node-name($node)} {
                    $node/@*,
                    for $child in $node/node()[not(local-name()="headsss")]
                        return local:update-text-node($config, $child)
                }
            else if ($node/@type = ("chapter", "compilation", "section")) then (
                let $notes := $node/tei:head/tei:note
                let $content := if ($notes) then
                        for $note at $i in $notes
                        return <p>
                            <ref target="{$node/@xml:id}" id="{concat($node/@xml:id, 'fn', $i)}" class="footnote" style="display: inline">
                                <sup>
                                    {($note/@n/string(), '*')[1]}
                                </sup>
                            </ref><span>&#160;</span>
                        </p>
                    else ()
                return element {node-name($node)} {(
                    $node/@*,
                    (
                        element {node-name($node/tei:head)} {(
                            (
                              $node/tei:head/@*,
                              attribute rend { if ($node/parent::tei:body) then "compilation-title" else "chapter-title" }
                            ),
                            $node/tei:head/node()
                        )}
                        ,
                        <tei:div xml:id="{$node/@xml:id}-generated-document" type="document" new-div="true">
                            {(
                            $content,
                            if ($node/tei:div[@type!='document']) then
                            (
                                <tei:milestone/>,
                                <head>Contents<tei:div/></head>,
                                <div>
                                    <ul>{
                                        for $document in $node/tei:div[@type='chapter']
                                        let $docnumber := frus:document-number($document)
                                        let $docid := frus:document-id($document)
                                        let $doctitle := frus:document-head-sans-number($document)
                                        let $docsource := frus:source-note($document)/string()
                                        let $docdateline := local:update-text-node($config, frus:dateline($document))
                                        let $docsummary := $document//tei:note[@type='summary']/string()
                                        return (
                                            <tei:milestone/>,
                                            <tei:ref rend="ref-title" target="#{$docid}">{if (not(starts-with($document/tei:head, concat($document/@n, '.')))) then concat('[', $docnumber, ']') else concat($docnumber, '. '), $doctitle}</tei:ref>,
                                            <opener><p class="dateline">{$docdateline}</p></opener>,
                                            if (exists($docsummary)) then <p>{$docsummary}</p> else (),
                                            <p class="sourcenote">{$docsource}</p>
                                        )
                                    }</ul>
                                </div>
                            )
                            else (
                                for $document in $node/tei:div[@type='document']
                                        let $docnumber := frus:document-number($document)
                                        let $docid := frus:document-id($document)
                                        let $doctitle := frus:document-head-sans-number($document)
                                        let $docsource := frus:source-note($document)/string()
                                        let $docdateline := local:update-text-node($config, frus:dateline($document))
                                        let $docsummary := $document//tei:note[@type='summary']/string()
                                        return (
                                            <tei:milestone/>,
                                            <tei:ref rend="ref-title" target="#{$docid}">{if (not(starts-with($document/tei:head, concat($document/@n, '.')))) then concat('[', $docnumber, ']') else concat($docnumber, '. '), $doctitle}</tei:ref>,
                                            <opener><p class="dateline">{$docdateline}</p></opener>,
                                            if (exists($docsummary)) then <p>{$docsummary}</p> else (),
                                            <p class="sourcenote">{$docsource}</p>
                                        )
                                    )
                                )
                            }
                        </tei:div>,
                        for $child in $node/node()[not(local-name()="head")]
                            return local:update-text-node($config, $child)
                    )
                )})
            else element {node-name($node)} {(
                    $node/@*,
                    for $child in $node/node()
                        return local:update-text-node($config, $child)
                )}
        default return if (local-name($node)='attachment') then
            (
                if ($node/@xml:id) then <anchor xml:id="{$node/@xml:id}" /> else (),
                $node/@*,
                for $child-node in $node/node()
                    return if (local-name($child-node)='head') then
                        <tei:p> {(
                            $child-node/@*[not(name()="rend")],
                            attribute rend {($child-node/@rend, 'xhtml-h5')},
                            for $child-child-node in $child-node/node()
                                return local:update-text-node($config, $child-child-node)
                        )}</tei:p>
                    else local:update-text-node($config, $child-node)
            )
        else if (count($node/node()) > 0) then
                    element {node-name($node)} {(
                        $node/@*,
                        for $child-node in $node/node()
                            return local:update-text-node($config, $child-node)
                        )}
                else
                    $node
};
declare function local:update-list-items($config, $node) {
    typeswitch ($node)
        case element(tei:graphic) return element {node-name($node)} {(
            ($node/@*[not(name()="url")], attribute url { local:cache-graphic-image($node) }),
            $node/node()
        )}
        case element(tei:list) return local:update-list($config, $node)
        default return element {node-name($node)} {(
                    $node/@*,
                    for $child-node in $node/*
                        return local:update-list-items($config, $child-node)
                    )}
};
declare function local:update-list($config, $node) {
    if ($node/*[1][local-name()="head"]) then
        element {node-name($node)} {(
            $node/@*,
            $node/node(),
            for $child-node in $node/node()
                return local:update-text-node($config, $child-node)
        )}
    else (<first>{node-name($node/*[1])}</first>, $node)
};
declare function local:about-xhtml($config) {
    doc('/db/apps/release/resources/boilerplate/frus-about.tei.xml')//tei:text/tei:body/tei:div
};

declare function local:title-xhtml($config) {
    let $volume-id := $config?metadata?id
    let $volume := collection('/db/apps/frus/bibiliography')/volume[@id eq $volume-id]
    let $editor-roles-to-display := ('primary', 'general')
    let $editors := $volume/editor[@role = $editor-roles-to-display and . ne '']
    let $published-year := $volume/published-year/string()
    let $office-name := $volume/office-name/string()
    let $office-parent := $volume/office-parent/string()
    let $body :=
        <tei:div>
            <tei:p rend="h3">{concat(frus:volume-title($volume-id, 'series'), ', ', frus:volume-title($volume-id, 'sub-series'))}</tei:p>
            <tei:milestone/>
            <tei:p rend="h3">H3:{frus:volume-title($volume-id, 'volume-number')}</tei:p>
            <tei:p rend="h1">{frus:volume-title($volume-id, 'volume')}</tei:p>
            {
            if ($editors) then
                <tei:list>
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
                        <tei:label>{$label}:</tei:label>
                        ,
                        for $ed in $editors-in-role
                        return
                            <tei:item>{$ed/string()}</tei:item>
                        )
                    }
                </tei:list>
            else ()
            }
            <tei:milestone/>
            <tei:p>
                United States Government Publishing Office <tei:pb/>
                Washington <tei:pb/>
                {$published-year}
            </tei:p>
            <tei:p>
                U.S. Department of State <tei:pb/>
                {$office-name} <tei:pb/>
                {$office-parent}
            </tei:p>
            <tei:milestone/>
            <tei:p>
                This ebook was generated on {format-date(current-date(), "[MNn] [D1], [Y0001]")}.<tei:pb/>
                Please visit the Office of the Historian <tei:ref target="http://history.state.gov/historicaldocuments/ebooks">ebooks web page</tei:ref> to access updates.
            </tei:p>
        </tei:div>
    let $title := 'Title page'
    return local:topic($config, $body, "title", "Title", "section", "title")
};

declare function local:toc-xhtml($config, $text, $suppress-documents) {
    local:topic($config, <tei:div>
        <tei:p rend="h2">Contents</tei:p>
        <tei:list>{
            local:frus-toc-to-li($text, $suppress-documents, $config?options)
        }</tei:list>
    </tei:div>, "table-of-contents", "Table of Contents", "section", "table-of-contents")    
};

declare function local:topic($config, $doc, $id, $title, $type) {
    local:topic($config, $doc, $id, $type, "")
};

declare function local:topic($config, $doc, $id, $title, $type, $subtype) {
    (: TODO: tell tei-publisher to not render the title instead of removing the title from the content :)
    let $content := for $node in $doc/node() return local:update-text-node($config, $node)
    return <tei:div type="{$type}" xml:id="{$id}"> {if ($subtype != "") then attribute subtype { $subtype } else ()}
        <tei:head>{$title}</tei:head>
        <tei:body>{$content}</tei:body>
    </tei:div>
};

declare function local:cover-xhtml($config, $node) {
    local:topic($config, <tei:div xmlns="http://www.w3.org/1999/xhtml">
        <tei:graphic url="{$config?metadata?id}/images/cover.jpg" alt="{$config?metadata?title}" id="cover-image"/>
    </tei:div>, "cover", "Cover", "section", "cover")
};

declare function epub3:save-frus-epub-to-disk($path-to-tei-document as xs:string, $option as xs:string*, $file-system-output-dir as xs:string) {
    (: volume id extracted from filename :)
    let $vol-id := substring-after(substring-before($path-to-tei-document, '.xml'), 'volumes/')
    (: images dir path specific to this volume :)
    let $images-collection := concat($epub3:cache-collection, '/', $vol-id, '/images')
    (: xml data of volume :)
    let $item := doc($path-to-tei-document)
    (: /teiHeader/fileDesc/titleStmt/title(5) :)
    let $titles := $item//tei:titleStmt/tei:title
    (: from the above titles, generate the following string: :)
    (: volume (series, sub-series, volume-number) :)
    let $title := normalize-space(concat($titles[@type eq 'volume'], ' (', string-join(($titles[@type eq 'series'], $titles[@type eq 'sub-series'], $titles[@type eq 'volume-number'])[. ne ''], ', '), ')'))
    (: Constant :)
    let $creator := 'Office of the Historian, Foreign Service Institute, United States Department of State'
    (: /text node :)
    let $text := $item//tei:text
    (: id+timestamp :)
    let $urn := concat($vol-id, '-', current-dateTime())
    (: resources dir (css, images, and about.xml) :)
    let $db-path-to-resources := '/db/apps/release/resources'
    (: get cover image path, if not found download it, if not found use default cover :)
    let $cover-uri :=
        if (util:binary-doc-available(concat($images-collection, '/', $vol-id, '.jpg'))) then
            concat($images-collection, '/', $vol-id, '.jpg')
        else
            let $href := concat('https://static.history.state.gov/frus/', $vol-id, '/covers/', $vol-id, '.jpg')
            let $request := <hc:request href="{$href}" method="head" http-version="1.1"/>
            let $response := hc:send-request($request)
            return
                if ($response/@status eq '200') then
                    let $check-collection :=
                        if (xmldb:collection-available($images-collection)) then
                            ()
                        else
                            (
                            xmldb:create-collection($epub3:cache-collection, $vol-id),
                            xmldb:create-collection(concat($epub3:cache-collection, '/', $vol-id), 'images')
                            )
                    let $request := <hc:request href="{$href}" method="get" http-version="1.1"/>
                    let $response := hc:send-request($request)
                    let $response-body := $response[2]
                    let $store := xmldb:store($images-collection, 'cover.jpg', $response-body, 'image/jpeg')
                    return
                        concat($images-collection, '/cover.jpg')
                else
                    (concat($db-path-to-resources, '/images/epub-cover.jpg'))
    return
        let $epub-dir := concat($file-system-output-dir, 'epub')
        let $mobi-dir := concat($file-system-output-dir, 'mobi-bound')
        let $filename := concat($file-system-output-dir, if ($option = 'mobi') then 'mobi-bound/' else 'epub/', $vol-id, '.3.epub')
        let $epub-zip := local:generate-epub($vol-id, $item, $title, $creator, $text, $urn, $db-path-to-resources, $cover-uri, $filename, $option)
        return
            <epub-created success="{file:serialize-binary(
                compression:zip($epub-zip, true()),
                $filename
            )}" filename="{$filename}" />
};
