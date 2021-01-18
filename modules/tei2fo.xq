xquery version "1.0";

(: A rough cut at a tei2fo renderer
 :
 : Instructions: Place this file in /db/fotest, 
 : along with china.xml, china-flag.jpg, and china_greatwall.jpg 
 :)

module namespace t2f="http://history.state.gov/ns/xquery/tei2fo";

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace xslfo="http://exist-db.org/xquery/xslfo";
import module namespace frus = "http://history.state.gov/ns/xquery/frus" at "frus.xql";
import module namespace hsg-config = "http://history.state.gov/ns/xquery/config" at '/db/apps/hsg-shell/modules/config.xqm';

import module namespace functx = "http://www.functx.com"; 

declare variable $t2f:fop-config := 
    (: Since Palatino is a system font we can have FOP auto-detect it, as documented at 
        http://www.oxygenxml.com/doc/ug-editor/tasks/add-font-to-builtin-FOP-simplified.html#add-font-to-builtin-FOP :)
    <fop version="1.0">
        <renderers>
            <renderer mime="application/pdf">
                {
                let $is-windows := starts-with(system:get-exist-home(), 'C:\')
                let $font-dir := if ($is-windows) then 'file:/C:\Windows\Fonts\' else 'file:/Library/Fonts/Microsoft/'
                return
                    <fonts>
                        <font kerning="yes" embed-url="http://localhost:8080/exist/apps/release/resources/fonts/pala.ttf" sub-font="Palatino">
                            <font-triplet name="Palatino" style="normal" weight="normal"/>
                        </font>
                        <font kerning="yes" embed-url="http://localhost:8080/cexist/apps/release/resources/fonts/palab.ttf" sub-font="Palatino Bold">
                            <font-triplet name="Palatino" style="normal" weight="bold"/>
                        </font>
                        <font kerning="yes" embed-url="http://localhost:8080/exist/apps/release/resources/fonts/palai.ttf" sub-font="Palatino Italic">
                            <font-triplet name="Palatino" style="italic" weight="normal"/>
                        </font>
                        <font kerning="yes" embed-url="http://localhost:8080/exist/apps/release/resources/fonts/palabi.ttf" sub-font="Palatino Bold Italic">
                            <font-triplet name="Palatino" style="italic" weight="bold"/>
                        </font>
                        <!--{
                        let $font-dir := 'file:/Users/joe/Library/Fonts/'
                        return
                        (
                        <font kerning="yes"
                            embed-url="{concat($font-dir, if ($is-windows) then 'pala.ttf' else 'MinionPro-Regular.ttf')}" sub-font="Minion Pro">
                            <font-triplet name="Minion Pro" style="normal" weight="normal"/>
                        </font>,
                        <font kerning="yes"
                            embed-url="{concat($font-dir, if ($is-windows) then 'palab.ttf' else 'MinionPro-Bold.ttf')}" sub-font="Minion Pro Bold">
                            <font-triplet name="Minion Pro" style="normal" weight="bold"/>
                        </font>,
                        <font kerning="yes"
                            embed-url="{concat($font-dir, if ($is-windows) then 'palai.ttf' else 'MinionPro-It.ttf')}" sub-font="Minion Pro Italic">
                            <font-triplet name="Minion Pro" style="italic" weight="normal"/>
                        </font>,
                        <font kerning="yes"
                            embed-url="{concat($font-dir, if ($is-windows) then 'palabi.ttf' else 'MinionPro-BoldIt.ttf')}" sub-font="Minion Pro Bold Italic">
                            <font-triplet name="Minion Pro" style="italic" weight="bold"/>
                        </font>
                        )
                        }-->
                    </fonts>
                }
            </renderer>
        </renderers>
        <hyphenation-pattern lang="en">en</hyphenation-pattern>
    </fop>;

declare function t2f:generate-pdf($fo as element(), $filename as xs:string) {
    let $fop-config := $t2f:fop-config
    return 
        (
        util:log('INFO', 'TEI-to-PDF: calling xslfo:render')
        ,
        xslfo:render($fo, "application/pdf", (), $fop-config)
        ,
        util:log('INFO', 'TEI-to-PDF: xslfo:render done')
        )
};

declare function t2f:frus-tei-to-pdf($vol-id as xs:string) {
    t2f:frus-tei-to-pdf($vol-id, ())
};

declare function t2f:frus-tei-to-pdf($vol-id as xs:string, $div-id as xs:string?) {
    let $fo := t2f:frus-tei-to-fo($vol-id, $div-id)
    let $filename := concat($vol-id, if ($div-id) then concat('_', $div-id) else (), '.pdf')
    return 
        t2f:generate-pdf($fo, $filename)
};

declare function t2f:frus-tei-to-fo($vol-id as xs:string) {
    t2f:frus-tei-to-fo($vol-id, ())
};

declare function t2f:frus-tei-to-fo($vol-id as xs:string, $div-id as xs:string?) {
    util:log('INFO', concat('TEI-to-PDF: starting ', $vol-id, if ($div-id) then concat('/', $div-id) else ()))
    ,
    let $text := 
        if ($div-id) then
            doc(concat('/db/apps/frus/volumes/', $vol-id, '.xml'))/id($div-id)
        else 
            doc(concat('/db/apps/frus/volumes/', $vol-id, '.xml'))/tei:TEI    
    let $parameters := 
        <parameters xmlns="">
            <!--<param name="output-type" value="{$output-type}"/>-->
            <param name="font-family" value="Palatino"/>
        </parameters>
    return
        t2f:render-frus($text, $parameters)
    ,
    util:log('INFO', 'TEI-to-PDF: TEI conversion to FO complete')
};

declare function t2f:render-frus($content as node()*, $options) as element() {
    let $volume-id := frus:volumeid($content)
    let $dc-title := normalize-space(concat(frus:volume-title($volume-id, 'volume'), ' (', frus:volume-title($volume-id, 'series'), ', ', frus:volume-title($volume-id, 'subseries'), ', ', frus:volume-title($volume-id, 'volumenumber'), ')'))
    let $dc-creator := 'Office of the Historian, U.S. Department of State'
    let $dc-description := normalize-space(frus:volume-title($volume-id, 'volume'))
    let $bookmark-tree := 
        (
        if ($content/self::tei:TEI) then
            (
            <fo:bookmark internal-destination="title">
                <fo:bookmark-title>Title Page</fo:bookmark-title>
            </fo:bookmark>,
            <fo:bookmark internal-destination="about">
                <fo:bookmark-title>About the Digital Edition</fo:bookmark-title>
            </fo:bookmark>,
            <fo:bookmark internal-destination="contents">
                <fo:bookmark-title>Table of Contents</fo:bookmark-title>
            </fo:bookmark>
            )
        else ()
        ,
        t2f:bookmark-passthru($content)
        )
    let $title-page-sequence := 
        if ($content/self::tei:TEI) then
            <fo:page-sequence master-reference="title" format="I" initial-page-number="1">
                <fo:flow flow-name="xsl-region-body">
                    {t2f:frus-title-page($volume-id)}
                </fo:flow>
            </fo:page-sequence>
        else ()
    let $page-sequences :=
        if ($content/self::tei:TEI) then 
            (
            t2f:section-to-page-sequence($content//tei:front, 'front-pgseq', $options, 'I', 'auto', 'auto')
            ,
            t2f:section-to-page-sequence($content//tei:body, 'body-pgseq', $options, '1', '1', 'auto')
            ,
            t2f:section-to-page-sequence($content//tei:back, 'back-pgseq', $options, '1', 'auto', 'auto')
            )
        else
            t2f:section-to-page-sequence($content, concat(if ($content/@xml:id) then $content/@xml:id else util:uuid(), '-pgseq'), $options, '1', '1', 'auto')
    return 
        t2f:render($content, $bookmark-tree, $title-page-sequence, $page-sequences, $options)
};

declare function t2f:frus-history-to-fo($vol-path as xs:string, $div-id as xs:string?, $output-type as xs:string, $renderer as xs:string) {
    util:log('INFO', concat('TEI-to-PDF: starting ', $vol-path, if ($div-id) then concat('/', $div-id) else ()))
    ,
    let $text := 
        if ($div-id) then
            doc($vol-path)/id($div-id)
        else 
            doc($vol-path)/tei:TEI
    let $font-family := 'Palatino'
    let $font-size-normal := 10
    let $font-size-small := $font-size-normal - 2
    let $page-width := if ($output-type = 'print') then if ($renderer = 'pdf') then '5.917in' else (: if ($renderer = 'distiller') then :) '6.667in' else '8.5in'
    let $page-height := if ($output-type = 'print') then if ($renderer = 'pdf') then '8.917in' else (: if ($renderer = 'distiller') then :) '9.667in' else '11in'
    let $page-margin-top := if ($renderer = 'distiller') then concat(.25 + .375, 'in') else '.25in'
    let $page-margin-bottom := if ($renderer = 'distiller') then concat(.25 + .375, 'in') else '.25in'
    let $page-margin-inner := if ($renderer = 'distiller') then concat(.875 + .375, 'in') else '.875in'
    let $page-margin-outer := if ($renderer = 'distiller') then concat(.6875 + .375, 'in') else '.6875in'
    let $options := 
        <parameters xmlns="">
            <param name="output-type" value="{$output-type}"/>
            <param name="renderer" value="{$renderer}"/>
            <param name="font-family" value="{$font-family}"/>
            <param name="font-size-normal" value="{$font-size-normal}"/>
            <param name="font-size-small" value="{$font-size-small}"/>
            <param name="space-after-paragraph" value="{
                if ($output-type = 'print') then 
                    '0mm'
                else 
                    '3mm'
                }"/>
            <param name="page-width" value="{$page-width}"/>
            <param name="page-height" value="{$page-height}"/>
            <param name="page-margin-top" value="{$page-margin-top}"/>
            <param name="page-margin-bottom" value="{$page-margin-bottom}"/>
            <param name="page-margin-inner" value="{$page-margin-inner}"/>
            <param name="page-margin-outer" value="{$page-margin-outer}"/>
            <param name="paragraph-text-indent" value="{
                if ($output-type = 'print') then 
                    '.25in'
                else 
                    '10mm'
                }"/>
            <!--
            <param name="fox:crop-box" value="media-box"/>
            <param name="fox:crop-offset" value=".375in"/>
            <param name="fox:bleed" value="0"/>-->
            <!--.125in-->
        </parameters>
    let $title-page-flows := if ($text/self::tei:TEI) then t2f:frus-history-cover-page($text, $options) else ()
    return
        t2f:render-frus-history($title-page-flows, $text, $options)
    ,
    util:log('INFO', 'TEI-to-PDF: TEI conversion to FO complete')
};

declare function t2f:frus-history-cover-page($content, $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := xs:integer($options//param[@name='font-size-normal']/@value)
    let $font-size-small := xs:integer($options//param[@name='font-size-small']/@value)
    let $output-type := $options//param[@name='output-type']/@value
    let $titles := $content//tei:titleStmt/tei:title
    let $title := $titles[@type eq 'complete']
    let $dc-title := normalize-space($title)
    let $dc-creator := 'Office of the Historian, Bureau of Public Affairs, United States Department of State'
    let $dc-description := $dc-title
    let $titlepage := $content//tei:titlePage
    let $authors := $titlepage//tei:name
    let $published-year := $content//tei:publicationStmt/tei:date
    let $db-path-to-resources := '/db/apps/release/resources'
    let $images-collection := '/db/apps/release/resources/images'
    let $filename := 'frus-history'
    let $margin-left := '1.4in'
    return
        if ($content/self::tei:TEI) then
            <fo:page-sequence master-reference="title" format="I" initial-page-number="1">
                <fo:static-content flow-name="title-footer">
                    <fo:block font-family="Palatino" font-size="10pt" >
                        <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black"/>
                        <fo:block margin-left="{$margin-left}" font-size="{$font-size-normal}pt">
                            <fo:block>U.S. Department of State</fo:block>
                            <fo:block>Office of the Historian</fo:block>
                            <fo:block>Bureau of Public Affairs</fo:block>
                            <fo:block>2015</fo:block>
                        </fo:block>
                    </fo:block>
                </fo:static-content>
                <fo:flow flow-name="xsl-region-body">
                    <fo:block id="title" font-family="{$font-family}" break-after="page">
                        <fo:block padding-top=".5in" padding-bottom=".25in">
                            <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black"/>
                        </fo:block>
                        <fo:block margin-left=".15in" padding-bottom="-.85in"><fo:external-graphic src="url('http://localhost:8080/exist/apps/release/resources/images/dos-seal-bw-2400dpi.tiff')" content-height="scale-to-fit" height="1in" content-width="1in"/></fo:block>
                        <fo:block font-size="20pt" font-weight="bold" margin-left="{$margin-left}" margin-bottom=".25in">Toward “Thorough, Accurate, and Reliable”:</fo:block>
                        <fo:block font-size="22pt" font-weight="bold" margin-left="{$margin-left}" margin-bottom="1.25in">A History of the <fo:inline font-style="italic">Foreign Relations of the United States</fo:inline> Series</fo:block>
                        {
                        for $author at $n in $authors 
                        return 
                            <fo:block margin-left="{$margin-left}" font-size="{$font-size-normal + 2}pt">{$author/string()}</fo:block>
                        }
                        {
                        if ($output-type = 'print') then 
                            ()
                        else 
                            <fo:block margin-left="{$margin-left}" font-size="{$font-size-small}pt" space-after="0">This PDF was generated on {format-date(current-date(), '[MNn] [D], [Y0001]')}. Please visit the Office of the Historian <fo:basic-link external-destination="url('http://history.state.gov/')" text-decoration="underline" color="blue">home page</fo:basic-link> to access updates.</fo:block>
                        }
                    </fo:block>
                </fo:flow>
            </fo:page-sequence>
        else ()
};

declare function t2f:render-frus-history($title-page-sequence as node()?, $content as node()*, $options) as element() {
    let $text := if ($content/self::tei:TEI) then $content else $content//tei:text
    let $bookmark-tree := (
        if ($content/self::tei:TEI) then
            (
            <fo:bookmark internal-destination="title">
                <fo:bookmark-title>Title Page</fo:bookmark-title>
            </fo:bookmark>,
            <fo:bookmark internal-destination="contents">
                <fo:bookmark-title>Table of Contents</fo:bookmark-title>
            </fo:bookmark>
            )
        else ()
        ,
        t2f:bookmark-passthru($content)
        )
    let $page-sequences :=
        if ($content/self::tei:TEI) then 
            (
            (: front matter :)
            for $div at $n in $content//tei:front//tei:div[@type = ('section')]
            return
                t2f:section-to-page-sequence($div, concat($div/@xml:id, '-pgseq'), $options, 'I', if ($n = 1) then 'auto-odd' else 'auto', 'end-on-even')
            ,
            (: toc :)
            t2f:section-to-page-sequence(t2f:toc(root($content)/*, $options), 'toc-pgseq', $options, 'I', 'auto-odd', 'end-on-even')
            ,
            (: body :)
            for $div at $n in $content//tei:body//tei:div[@type = ('part', 'chapter')]
            let $section :=
                (: pull part into its own page sequence, consisting just of the part head :)
                if ($div/@type = 'part') then 
                    element tei:div {$div/@*, $div/tei:head}
                else 
                    $div
            return
                t2f:section-to-page-sequence($section, concat($div/@xml:id, '-pgseq'), $options, '1', if ($n eq 1) then '1' else 'auto', (: start all "part" divs on odd pages :) if ($div/@type='part') then 'auto' else if ($div/following-sibling::element()[1][self::tei:div/@type = "chapter"]) then 'auto' else 'end-on-even')
            ,
            (: back matter :)
            for $div at $n in $content//tei:back//tei:div[@type = ('section')]
            return
                t2f:section-to-page-sequence($div, concat($div/@xml:id, '-pgseq'), $options, '1', 'auto', 'auto')
            )
        else
            t2f:section-to-page-sequence($content, concat(if ($content/@xml:id) then $content/@xml:id else util:uuid(), '-pgseq'), $options, '1', '1', 'auto')
    return 
        t2f:render($content, $bookmark-tree, $title-page-sequence, $page-sequences, $options)
};

declare function t2f:public-diplomacy-to-fo($vol-path as xs:string, $div-id as xs:string?, $output-type as xs:string, $renderer as xs:string) {
    util:log('INFO', concat('TEI-to-PDF: starting ', $vol-path, if ($div-id) then concat('/', $div-id) else ()))
    ,
    let $text := 
        if ($div-id) then
            doc($vol-path)/id($div-id)
        else 
            doc($vol-path)/tei:TEI
    let $font-family := 'Palatino'
    let $font-size-normal := 10
    let $font-size-small := $font-size-normal - 2
    let $page-width := if ($output-type = 'paperback') then '4.25in' else if ($output-type = 'print') then if ($renderer = 'pdf') then '5.917in' else (: if ($renderer = 'distiller') then :) '6.667in' else '8.5in'
    let $page-height := if ($output-type = 'paperback') then '6.25in' else if ($output-type = 'print') then if ($renderer = 'pdf') then '8.917in' else (: if ($renderer = 'distiller') then :) '9.667in' else '11in'
    let $page-margin-top := if ($renderer = 'distiller') then concat(.25 + .375, 'in') else '.25in'
    let $page-margin-bottom := if ($renderer = 'distiller') then concat(.25 + .375, 'in') else '.25in'
    let $page-margin-inner := if ($renderer = 'distiller') then concat(.875 + .375, 'in') else '.875in'
    let $page-margin-outer := if ($renderer = 'distiller') then concat(.6875 + .375, 'in') else '.6875in'
    let $options := 
        <parameters xmlns="">
            <param name="output-type" value="{$output-type}"/>
            <param name="renderer" value="{$renderer}"/>
            <param name="font-family" value="{$font-family}"/>
            <param name="font-size-normal" value="{$font-size-normal}"/>
            <param name="font-size-small" value="{$font-size-small}"/>
            <param name="space-after-paragraph" value="{
                if ($output-type = ('print', 'paperback')) then 
                    '0mm'
                else 
                    '3mm'
                }"/>
            <param name="page-width" value="{$page-width}"/>
            <param name="page-height" value="{$page-height}"/>
            <param name="page-margin-top" value="{$page-margin-top}"/>
            <param name="page-margin-bottom" value="{$page-margin-bottom}"/>
            <param name="page-margin-inner" value="{$page-margin-inner}"/>
            <param name="page-margin-outer" value="{$page-margin-outer}"/>
            <param name="paragraph-text-indent" value="{
                if ($output-type = ('print', 'paperback')) then 
                    '.25in'
                else 
                    '10mm'
                }"/>
            <!--
            <param name="fox:crop-box" value="media-box"/>
            <param name="fox:crop-offset" value=".375in"/>
            <param name="fox:bleed" value="0"/>-->
            <!--.125in-->
        </parameters>
    let $title-page-flows := if ($text/self::tei:TEI) then t2f:public-diplomacy-cover-page($text, $options) else ()
    return
        t2f:render-public-diplomacy($title-page-flows, $text, $options)
    ,
    util:log('INFO', 'TEI-to-PDF: TEI conversion to FO complete')
};

declare function t2f:public-diplomacy-cover-page($content, $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := xs:integer($options//param[@name='font-size-normal']/@value)
    let $font-size-small := xs:integer($options//param[@name='font-size-small']/@value)
    let $output-type := $options//param[@name='output-type']/@value
    let $titles := $content//tei:titleStmt/tei:title
    let $title := $titles[@type eq 'complete']
    let $dc-title := normalize-space($title)
    let $dc-creator := 'Office of the Historian, Bureau of Public Affairs, United States Department of State'
    let $dc-description := $dc-title
    let $titlepage := $content//tei:titlePage
    let $authors := $titlepage//tei:name
    let $published-year := $content//tei:publicationStmt/tei:date
    let $db-path-to-resources := '/db/apps/release/resources'
    let $images-collection := '/db/apps/release/resources/images'
    let $filename := 'public-diplomacy'
    let $margin-left := '1.4in'
    return
        if ($content/self::tei:TEI) then
            <fo:page-sequence master-reference="title" format="I" initial-page-number="1">
                <fo:static-content flow-name="title-footer">
                    <fo:block font-family="Palatino" font-size="10pt" >
                        <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black"/>
                        <fo:block margin-left="{$margin-left}" font-size="{$font-size-normal}pt">
                            <fo:block>U.S. Department of State</fo:block>
                            <fo:block>Office of the Historian</fo:block>
                            <fo:block>Bureau of Public Affairs</fo:block>
                            <fo:block>{format-date(current-date(), '[Y0001]')}</fo:block>
                        </fo:block>
                    </fo:block>
                </fo:static-content>
                <fo:flow flow-name="xsl-region-body">
                    <fo:block id="title" font-family="{$font-family}" break-after="page">
                        <fo:block padding-top=".5in" padding-bottom=".25in">
                            <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black"/>
                        </fo:block>
                        <fo:block margin-left=".15in" padding-bottom="-.85in"><fo:external-graphic src="url('http://localhost:8080/exist/apps/release/resources/images/dos-seal-bw-2400dpi.tiff')" content-height="scale-to-fit" height="1in" content-width="1in"/></fo:block>
                        <fo:block font-size="24pt" font-weight="bold" margin-left="{$margin-left}" margin-bottom=".25in">The Public Diplomacy Moment:</fo:block>
                        <fo:block font-size="20pt" font-weight="bold" margin-left="{$margin-left}" margin-bottom=".25in">The Department of State and the Transformation of U.S. Public Diplomacy</fo:block>
                        <fo:block font-size="20pt" font-weight="bold" margin-left="{$margin-left}" margin-bottom="1.25in">1999–Present</fo:block>
                    
                        {
                        for $author at $n in $authors 
                        return 
                            <fo:block margin-left="{$margin-left}" font-size="{$font-size-normal + 2}pt">{$author/string()}</fo:block>
                        }
                        {
                        if ($output-type = ('print', 'paperback')) then 
                            ()
                        else 
                            <fo:block margin-left="{$margin-left}" font-size="{$font-size-small}pt" space-after="0">This PDF was generated on {format-date(current-date(), '[MNn] [D], [Y0001]')}. Please contact the Office of the Historian to request updates.</fo:block>
                        }
                    </fo:block>
                </fo:flow>
            </fo:page-sequence>
        else ()
};

declare function t2f:render-public-diplomacy($title-page-sequence as node()?, $content as node()*, $options) as element() {
    let $text := if ($content/self::tei:TEI) then $content else $content//tei:text
    let $bookmark-tree := (
        if ($content/self::tei:TEI) then
            (
            <fo:bookmark internal-destination="title">
                <fo:bookmark-title>Title Page</fo:bookmark-title>
            </fo:bookmark>,
            <fo:bookmark internal-destination="contents">
                <fo:bookmark-title>Table of Contents</fo:bookmark-title>
            </fo:bookmark>
            )
        else ()
        ,
        t2f:bookmark-passthru($content)
        )
    let $page-sequences :=
        if ($content/self::tei:TEI) then 
            (
            (: front matter :)
            for $div at $n in $content//tei:front//tei:div[@type = ('section')]
            return
                t2f:section-to-page-sequence($div, concat($div/@xml:id, '-pgseq'), $options, 'I', if ($n = 1) then 'auto-odd' else 'auto', 'end-on-even')
            ,
            (: toc :)
            t2f:section-to-page-sequence(t2f:toc(root($content)/*, $options), 'toc-pgseq', $options, 'I', 'auto-odd', 'end-on-even')
            ,
            (: body :)
            for $div at $n in $content//tei:body//tei:div[@type = ('part', 'chapter')]
            let $section :=
                (: pull part into its own page sequence, consisting just of the part head :)
                if ($div/@type = 'part') then 
                    element tei:div {$div/@*, $div/tei:head}
                else 
                    $div
            return
                t2f:section-to-page-sequence($section, concat($div/@xml:id, '-pgseq'), $options, '1', if ($n eq 1) then '1' else 'auto', (: start all "part" divs on odd pages :) if ($div/@type='part') then 'auto' else if ($div/following-sibling::element()[1][self::tei:div/@type = "chapter"]) then 'auto' else 'end-on-even')
            ,
            (: back matter :)
            for $div at $n in $content//tei:back//tei:div[@type = ('section')]
            return
                t2f:section-to-page-sequence($div, concat($div/@xml:id, '-pgseq'), $options, '1', 'auto', 'auto')
            )
        else
            t2f:section-to-page-sequence($content, concat(if ($content/@xml:id) then $content/@xml:id else util:uuid(), '-pgseq'), $options, '1', '1', 'auto')
    return 
        t2f:render($content, $bookmark-tree, $title-page-sequence, $page-sequences, $options)
};

declare function t2f:section-to-page-sequence($content, $id, $options, $page-number-style, $initial-page-number, $force-page-count) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    return
        <fo:page-sequence master-reference="{if ($content/@xml:id = 'appendix-a') then 'rest-no-running-heads' else if ($content/@xml:id = 'index') then 'two-column-section' else 'section'}" initial-page-number="{$initial-page-number}" format="{$page-number-style}" force-page-count="{$force-page-count}" language="en" id="{$id}">
            <fo:static-content flow-name="non-blank-after">
                <fo:block>
                    <!-- content for non-blank page footers -->
                </fo:block>
            </fo:static-content>        
            <fo:static-content flow-name="blank-before">
                <fo:block>
                    <!-- content for blank page headers -->
                </fo:block>
            </fo:static-content>
            <fo:static-content flow-name="blank-after">
                <fo:block>
                    <!-- content for blank page footers -->
                </fo:block>
            </fo:static-content>
            <fo:static-content flow-name="first-odd-after">
                <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-align="right" line-height=".9em">
                    <!-- content for first page footers on the odd side -->
                    {
                    (: prevent page numbers from appearing on first page of "parts" or on the "epigraph" :)
                    if ($content/@type = 'part' or $content/@xml:id = 'epigraph') then 
                        () 
                    else 
                        <fo:page-number/>
                    }
                </fo:block>
            </fo:static-content>
            <fo:static-content flow-name="first-even-after">
                <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-align="left" line-height=".9em">
                    <!-- content for first page footers on the even side -->
                    <fo:page-number/>
                </fo:block>
            </fo:static-content>
            <fo:static-content flow-name="odd-before">
                {
                (: prevent running heads from appearing on 2nd & subsequent pages of appendix a:)
                if ($content/@xml:id = 'appendix-a') then 
                    <fo:block/> 
                else 
                    (
                    <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-align="right" line-height=".9em">
                        <!-- content for odd page headers -->
                        <fo:inline padding-right=".125in">
                            <fo:retrieve-marker retrieve-class-name="running-head-odd" retrieve-boundary="page" retrieve-position="first-starting-within-page"/>
                        </fo:inline>
                        <fo:page-number/>
                    </fo:block>
                    ,
                    <fo:block text-align-last="justify" line-height="1pt">
                        <fo:leader leader-pattern="rule" rule-thickness="1pt" rule-style="solid" color="black"/>
                    </fo:block>
                    )
                }
            </fo:static-content>
            <fo:static-content flow-name="even-before">
                {
                (: prevent running heads from appearing on 2nd & subsequent pages of appendix a:)
                if ($content/@xml:id = 'appendix-a') then 
                    <fo:block/> 
                else 
                    (
                    <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-align="left" line-height=".9em">
                        <!-- content for even page headers -->
                        <fo:page-number/>
                        <fo:inline padding-left=".125in">
                            <fo:retrieve-marker retrieve-class-name="running-head-even" retrieve-boundary="page" retrieve-position="first-starting-within-page"/>
                        </fo:inline>
                    </fo:block>
                    ,
                    <fo:block text-align-last="justify" line-height="1pt">
                        <fo:leader leader-pattern="rule" rule-thickness="1pt" rule-style="solid" color="black"/>
                    </fo:block>
                    )
                }
            </fo:static-content>
            <fo:static-content flow-name="xsl-footnote-separator">
                <fo:block>
                    <fo:leader leader-pattern="rule" leader-length=".75in" rule-thickness="0.5pt" rule-style="solid" color="black"/>
                </fo:block>
            </fo:static-content>
            <fo:flow flow-name="xsl-region-body">
                {
                if ($content/self::tei:*) then 
                    t2f:main($content, $options)
                else 
                    $content
                }
            </fo:flow>
        </fo:page-sequence>
};

declare function t2f:render(
    $content as element(), 
    $bookmark-tree as element()*,
    $title-page-sequence as element()*,
    $page-sequences as element()*,
    $options
    )
{
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $page-width := $options//param[@name='page-width']/@value
    let $page-height := $options//param[@name='page-height']/@value
    let $page-margin-top := $options//param[@name='page-margin-top']/@value
    let $page-margin-bottom := $options//param[@name='page-margin-bottom']/@value
    let $page-margin-inner := $options//param[@name='page-margin-inner']/@value
    let $page-margin-outer := $options//param[@name='page-margin-outer']/@value
    let $renderer := $options//param[@name='renderer']/@value
    let $crop-box := $options//param[@name='fox:crop-box']/@value
    let $crop-offset := $options//param[@name='fox:crop-offset']/@value
    let $bleed := $options//param[@name='fox:bleed']/@value
    let $titles := root($content)//tei:titleStmt/tei:title
    let $title := $titles[@type eq 'complete']
    let $dc-title := normalize-space($title)
    let $dc-creator := 'Office of the Historian, Bureau of Public Affairs, United States Department of State'
    let $dc-description := ()
    let $titlepage := $content//tei:titlePage
    let $authors := $titlepage//tei:name
    let $published-year := $content//tei:publicationStmt/tei:date
    return
        <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:fox="http://xmlgraphics.apache.org/fop/extensions" font-family="{$font-family}">
            <fo:layout-master-set>
                <fo:simple-page-master master-name="title-page" 
                    page-width="{$page-width}" 
                    page-height="{$page-height}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                    <fo:region-body 
                        margin-top="0"
                        margin-bottom="0"/>
                    <fo:region-after region-name="title-footer" extent="1.15in"/>
                </fo:simple-page-master>
                
                <!-- layout for a first page on the odd side -->
                <fo:simple-page-master master-name="first-odd"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".825in" 
                            margin-bottom=".375in"/>
                        <fo:region-after
                            region-name="first-odd-after"
                            extent=".25in"/>
                </fo:simple-page-master>
                
                <!-- layout for a first page on the even side -->
                <fo:simple-page-master master-name="first-even"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".825in" 
                            margin-bottom=".375in"/>
                        <fo:region-after
                            region-name="first-even-after"
                            extent=".25in"/>
                </fo:simple-page-master>
                
                <!-- layout for odd pages -->
                <fo:simple-page-master master-name="odd"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".35in" 
                            margin-bottom=".25in"/>
                        <fo:region-before
                            region-name="odd-before"
                            extent=".25in"/>
                        <fo:region-after
                            region-name="non-blank-after"
                            extent=".1in"/>
                </fo:simple-page-master>
                
                <!-- layout for even pages -->
                <fo:simple-page-master master-name="even"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".35in" 
                            margin-bottom=".25in"/>
                        <fo:region-before
                            region-name="even-before"
                            extent=".25in"/>
                        <fo:region-after
                            region-name="non-blank-after"
                            extent=".1in"/>
                </fo:simple-page-master>
                
                <!-- layout for blank pages -->
                <fo:simple-page-master master-name="blank"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".5in" 
                            margin-bottom=".5in"/>
                        <fo:region-before
                            region-name="blank-before"
                            extent=".5in"/>
                        <fo:region-after
                            region-name="blank-after"
                            extent=".25in"/>
                </fo:simple-page-master>
                
                <!-- layout for odd pages without running heads -->
                <fo:simple-page-master master-name="odd-no-running-head"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body 
                            margin-top=".25in" 
                            margin-bottom="0"/>
                </fo:simple-page-master>
                
                <!-- layout for even pages without running heads-->
                <fo:simple-page-master master-name="even-no-running-head"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".25in" 
                            margin-bottom="0"/>
                </fo:simple-page-master>
                
                <!-- layout for a first two-column page on the odd side -->
                <fo:simple-page-master master-name="two-column-first-odd"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".825in" 
                            margin-bottom=".375in"
                            column-count="2"/>
                        <fo:region-after
                            region-name="first-odd-after"
                            extent=".25in"/>
                </fo:simple-page-master>
                
                <!-- layout for a two-column first page on the even side -->
                <fo:simple-page-master master-name="two-column-first-even"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".825in" 
                            margin-bottom=".375in"
                            column-count="2"/>
                        <fo:region-after
                            region-name="first-even-after"
                            extent=".25in"/>
                </fo:simple-page-master>
                
                <!-- layout for two-column odd pages -->
                <fo:simple-page-master master-name="two-column-odd"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-inner}" 
                    margin-right="{$page-margin-outer}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".35in" 
                            margin-bottom=".25in"
                            column-count="2"/>
                        <fo:region-before
                            region-name="odd-before"
                            extent=".25in"/>
                        <fo:region-after
                            region-name="non-blank-after"
                            extent=".1in"/>
                </fo:simple-page-master>
                
                <!-- layout for two-column even pages -->
                <fo:simple-page-master master-name="two-column-even"
                    page-height="{$page-height}"  
                    page-width="{$page-width}"
                    margin-top="{$page-margin-top}" 
                    margin-bottom="{$page-margin-bottom}"
                    margin-left="{$page-margin-outer}" 
                    margin-right="{$page-margin-inner}">
                    {
                    (:if ($renderer = 'pdf') then
                        (
                        attribute fox:crop-box {$crop-box},
                        attribute fox:crop-offset {$crop-offset},
                        if ($bleed = '0') then () else attribute fox:bleed {$bleed} 
                        )
                    else:) ()
                    }
                        <fo:region-body
                            margin-top=".35in" 
                            margin-bottom=".25in"
                            column-count="2"/>
                        <fo:region-before
                            region-name="even-before"
                            extent=".25in"/>
                        <fo:region-after
                            region-name="non-blank-after"
                            extent=".1in"/>
                </fo:simple-page-master>
                
                <fo:page-sequence-master master-name="title">
                    <fo:repeatable-page-master-alternatives>
                        <fo:conditional-page-master-reference
                            master-reference="blank"
                            blank-or-not-blank="blank" />
                        <fo:conditional-page-master-reference
                            master-reference="title-page"
                            page-position="first"
                            odd-or-even="odd" />
                    </fo:repeatable-page-master-alternatives>
                </fo:page-sequence-master>
                
                <fo:page-sequence-master master-name="section">
                    <fo:repeatable-page-master-alternatives>
                        <fo:conditional-page-master-reference
                            master-reference="blank"
                            blank-or-not-blank="blank" />
                        <fo:conditional-page-master-reference
                            master-reference="odd"
                            page-position="rest"
                            odd-or-even="odd" />
                        <fo:conditional-page-master-reference
                            master-reference="even"
                            page-position="rest"
                            odd-or-even="even" />
                        <fo:conditional-page-master-reference
                            master-reference="first-odd"
                            page-position="first" 
                            odd-or-even="odd"/>
                        <fo:conditional-page-master-reference
                            master-reference="first-even"
                            page-position="first" 
                            odd-or-even="even"/>
                    </fo:repeatable-page-master-alternatives>
                </fo:page-sequence-master>
                
                <fo:page-sequence-master master-name="rest-no-running-heads">
                    <fo:repeatable-page-master-alternatives>
                        <fo:conditional-page-master-reference
                            master-reference="blank"
                            blank-or-not-blank="blank" />
                        <fo:conditional-page-master-reference
                            master-reference="odd-no-running-head"
                            page-position="rest"
                            odd-or-even="odd" />
                        <fo:conditional-page-master-reference
                            master-reference="even-no-running-head"
                            page-position="rest"
                            odd-or-even="even" />
                        <fo:conditional-page-master-reference
                            master-reference="first-odd"
                            page-position="first" 
                            odd-or-even="odd"/>
                        <fo:conditional-page-master-reference
                            master-reference="first-even"
                            page-position="first" 
                            odd-or-even="even"/>
                    </fo:repeatable-page-master-alternatives>
                </fo:page-sequence-master>
                
                <fo:page-sequence-master master-name="two-column-section">
                    <fo:repeatable-page-master-alternatives>
                        <fo:conditional-page-master-reference
                            master-reference="blank"
                            blank-or-not-blank="blank" />
                        <fo:conditional-page-master-reference
                            master-reference="two-column-odd"
                            page-position="rest"
                            odd-or-even="odd" />
                        <fo:conditional-page-master-reference
                            master-reference="two-column-even"
                            page-position="rest"
                            odd-or-even="even" />
                        <fo:conditional-page-master-reference
                            master-reference="two-column-first-odd"
                            page-position="first" 
                            odd-or-even="odd"/>
                        <fo:conditional-page-master-reference
                            master-reference="two-column-first-even"
                            page-position="first" 
                            odd-or-even="even"/>
                    </fo:repeatable-page-master-alternatives>
                </fo:page-sequence-master>
                
            </fo:layout-master-set>
            
            <!-- PDF metadata: http://xmlgraphics.apache.org/fop/1.1/metadata.html -->
            <fo:declarations>
                <x:xmpmeta xmlns:x="adobe:ns:meta/">
                    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
                            <!-- Dublin Core properties go here -->
                            <dc:title>{$dc-title}</dc:title>
                            <dc:creator>{$dc-creator}</dc:creator>
                            <dc:description>{$dc-description}</dc:description>
                        </rdf:Description>
                        <!-- omit XMP Basic properties, like xmp:CreatorTool, since eXist-db supplies it nicely as eXist-db with Apache FOP -->
                        <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
                            <!-- Adobe PDF Schema properties go here -->
                            <!--<pdf:Keywords>Document title</pdf:Keywords>-->
                        </rdf:Description>
                    </rdf:RDF>
                </x:xmpmeta>
            </fo:declarations>
            <fo:bookmark-tree>
                { $bookmark-tree }
            </fo:bookmark-tree>
            { 
            $title-page-sequence
            ,
            $page-sequences
            }
        </fo:root>
};


declare function t2f:main($nodes as node()*, $options) as item()* {
    for $node in $nodes
    (:let $log := if ($node/self::tei:div) then util:log('INFO', concat('TEI-to-PDF: processing ', $node/@xml:id)) else ():)
    return
        typeswitch($node)
            case text() return $node
            case element(tei:TEI) return t2f:TEI($node, $options)
            case element(tei:text) return t2f:text($node, $options)
            case element(tei:front) return t2f:front($node, $options)
            case element(tei:body) return t2f:body($node, $options)
            case element(tei:back) return t2f:back($node, $options)
            case element(tei:div) return t2f:div($node, $options)
            case element(tei:head) return t2f:head($node, $options)
            case element(tei:p) return t2f:p($node, $options)
            case element(tei:byline) return t2f:byline($node, $options)
            case element(tei:quote) return t2f:quote($node, $options)
            case element(tei:hi) return t2f:hi($node, $options)
            case element(tei:del) return t2f:del($node, $options)
            case element(tei:term) return t2f:term($node, $options)
            case element(tei:anchor) return t2f:anchor($node, $options)
            case element(tei:dateline) return t2f:dateline($node, $options)
            case element(tei:ref) return t2f:ref($node, $options)
            case element(tei:lb) return t2f:lb($node, $options)
            case element(tei:pb) return t2f:pb($node, $options)
            case element(tei:note) return t2f:note($node, $options)
            case element(tei:list) return t2f:list($node, $options)
            case element(tei:item) return t2f:item($node, $options)
            case element(tei:closer) return t2f:closer($node, $options)
            case element(tei:signed) return t2f:signed($node, $options)
            case element(tei:figure) return t2f:figure($node, $options)
            case element(tei:graphic) return t2f:graphic($node, $options)
            case element(tei:listBibl) return t2f:listBibl($node, $options)
            case element(tei:bibl) return t2f:bibl($node, $options)
            case element(tei:table) return t2f:table($node, $options)
            case element(tei:row) return t2f:row($node, $options)
            case element(tei:cell) return t2f:cell($node, $options)
            case element(tei:titlePage) return ()
            default return t2f:recurse($node, $options) 
};

declare function t2f:recurse($content as node()*, $options) as item()* {
    let $adjacent-nodes := ('hi', 'ref', 'persName', 'placeName', 'date', 'gloss')
    let $nodes := $content/node()
    let $node-count := count($nodes)
    for $node at $n in $nodes
    return 
        (
        t2f:main($node, $options)
        ,
        (: it helps if the adjacent nodes have already had trailing spaces before close tag removed, e.g., find \s+</hi> replace with </hi> :)
        if ($n < $node-count) then
            if ($node instance of element() and $node/name() = $adjacent-nodes and $nodes[$n + 1] instance of element() and $nodes[$n + 1]/name() = $adjacent-nodes) then '&#160;' else ()
        else ()
        )
};

declare function t2f:TEI($node as element(tei:TEI), $options) as element() {
    <fo:block>{t2f:recurse($node, $options)}</fo:block>
};

declare function t2f:text($node as element(tei:text), $options) as element() {
    <fo:block>{t2f:recurse($node, $options)}</fo:block>
};

declare function t2f:front($node as element(tei:front), $options) as element() {
    <fo:block>{t2f:recurse($node, $options)}</fo:block>
};

declare function t2f:body($node as element(tei:body), $options) as element() {
    <fo:block>
        <!--<fo:marker marker-class-name="heading">{normalize-space(frus:volume-title(frus:volumeid($node), 'volume'))}</fo:marker>-->
        {t2f:recurse($node, $options)}
    </fo:block>
};

declare function t2f:back($node as element(tei:back), $options) as element() {
    <fo:block>{t2f:recurse($node, $options)}</fo:block>
};

declare function t2f:div($node as element(tei:div), $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $footnote-reference-font-size := $font-size-small - 2
    return
        if ($node/@xml:id = $t2f:frus-div-xmlids-to-suppress) then ()
        else if ($node/@xml:id = 'index' and $node//tei:ref[starts-with(@target, '#pg')]) then 
            <fo:block font-family="{$font-family}" id="index">
                <fo:block font-size="24pt" space-before="5mm" space-after="5mm">Index</fo:block>
                <fo:block>Note: The original index has been suppressed in this ebook; for more information, see <fo:basic-link internal-destination="about" text-decoration="underline" color="blue">“About the Digital Edition.”</fo:basic-link></fo:block>
            </fo:block>
        else
            <fo:block font-family="{$font-family}"  line-height-shift-adjustment="disregard-shifts">
                {if ($node/@type = ('document', 'chapter', 'part') or $node/ancestor::tei:front or $node/ancestor::tei:back) then attribute break-after {'page'} else ()}
                {if ($node/@xml:id) then attribute id {$node/@xml:id} else () }
                {t2f:recurse($node, $options)}
                {
                if ($node/@rend="endnotes") then
                    if ($node//tei:note) then
                        (
                        <fo:block>
                            <fo:leader leader-pattern="rule" leader-length=".5in" rule-thickness="0.5pt" rule-style="solid" color="black"/>
                        </fo:block>,
                        <fo:block>
                            <fo:list-block provisional-distance-between-starts=".25in" provisional-label-separation=".1in" padding-bottom=".125em" margin-left="{if ($node/parent::tei:item/parent::tei:list/parent::tei:p) then 'from-nearest-specified-value(margin-left) * -2' else '0'}" text-indent="0">
                                {
                                for $note in $node//tei:note
                                return
                                    <fo:list-item 
                                        id="{
                                            if ($note/@xml:id) then 
                                                $note/@xml:id
                                            else 
                                                concat($note/ancestor::tei:div[@xml:id][1]/@xml:id, "_fn", $node/@n)
                                        }">
                                        <fo:list-item-label end-indent="label-end()">
                                            <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" baseline-shift="super">
                                                {$note/@n/string()}.
                                            </fo:block>
                                        </fo:list-item-label>
                                        <fo:list-item-body start-indent="body-start()">
                                            <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" font-weight="normal">
                                                {t2f:recurse($note, $options)}
                                            </fo:block>
                                        </fo:list-item-body>
                                    </fo:list-item>
                                }
                            </fo:list-block>
                        </fo:block>
                        )
                    else ()
                else ()
                }
            </fo:block>
};

declare function t2f:title($node as element(tei:title), $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        <fo:block font-family="{$font-family}" 
            font-size="24pt" space-before="5mm" space-after="5mm">
            {t2f:recurse($node, $options)}
        </fo:block>
};

declare function t2f:head($node as element(tei:head), $options) as element()* {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        if ($node/@type = 'shortened-for-running-head') then ()
        else if ($node/parent::tei:div[@type eq 'document']) then
            <fo:block font-family="{$font-family}" font-weight="bold" font-size="{$font-size-normal}pt" space-before="5mm" space-after="5mm">
                {
                if (matches($node/string(), '^\s*?\d+\.') or matches($node/string(), '^\s*?No\. \d+')) then 
                    t2f:recurse($node, $options)
                else
                    (
                    concat($node/parent::tei:div/@n, '. '), 
                    t2f:recurse($node, $options)
                    )
                }
            </fo:block>
        else if ($node/parent::tei:div) then
            (
            <fo:marker marker-class-name="running-head-even">{
                root($node)//tei:title[@type='short']/string()
            }</fo:marker>,
            <fo:marker marker-class-name="running-head-odd">{
                if ($node/following-sibling::tei:head[1]/@type = 'shortened-for-running-head') then 
                    t2f:recurse($node/following-sibling::tei:head[1], $options) 
                else 
                    t2f:recurse(functx:remove-elements-deep($node, 'note'), $options)
                (: if (contains($node, ':')) then substring-before($node, ': ') else t2f:recurse($node, $options) :)
            }</fo:marker>,
            <fo:block font-family="{$font-family}" font-size="{26 - count($node/ancestor::tei:div) * 2}pt" space-before="5mm" space-after="5mm">
                {if ($node/parent::tei:div/@type = 'compilation') then attribute font-weight {"bold"} else ()}
                {if ($node/parent::tei:div/@xml:id = 'index') then attribute span {"all"} else ()}
                {
                if ($node/parent::tei:div/@xml:id = 'epigraph') then 
                    '&#160;'
                else 
                    t2f:recurse($node, $options)
                }
            </fo:block>
            )
        else if ($node/parent::tei:figure) then
            (: suppress caption for specific images :)
            if ($node/parent::tei:figure/tei:graphic/@url = ("frus-lag") ) then 
                ()
            else
                <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" space-after="5mm">
                    {t2f:recurse($node, $options)}
                </fo:block>
        else if ($node/parent::tei:list) then
            (: start-indent=0mm to force list head to flush left:)
            <fo:list-item space-after="3mm">
                <fo:list-item-label end-indent="label-end()">
                    <fo:block/>
                </fo:list-item-label>
                <fo:list-item-body start-indent="0mm">
                    <fo:block font-size="{$font-size-small}pt">{t2f:recurse($node, $options)}</fo:block>
                </fo:list-item-body>
            </fo:list-item>
        else if ($node/parent::tei:table) then
            <fo:block font-family="{$font-family}" text-align="center" space-after="5mm">
                {t2f:recurse($node, $options)}
            </fo:block>
        else 
            <fo:block>
                {t2f:recurse($node, $options)}
            </fo:block>
};

declare function t2f:p($node as element(tei:p), $options) {
    let $rend := $node/@rend
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := xs:integer($options//param[@name='font-size-normal']/@value)
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $output-type := $options//param[@name='output-type']/@value
    let $space-after-paragraph := $options//param[@name='space-after-paragraph']/@value
    let $paragraph-text-indent := $options//param[@name='paragraph-text-indent']/@value
    let $title-spacing-before := $font-size-normal * .75
    let $title-spacing-after := $font-size-normal * .5
    let $quote-paragraph-spacing := $font-size-normal div 4
    let $is-back-matter := $node/ancestor::tei:back
    let $div-id := $node/ancestor::tei:div[1]/@xml:id
    return
        if ($rend = 'sectiontitleital') then
            <fo:block font-family="{$font-family}" font-style="italic" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" space-before="{$title-spacing-before}pt" space-after="{$title-spacing-after}pt" keep-with-next.within-page="always">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'sectiontitlebold') then
            <fo:block font-family="{$font-family}" font-weight="bold" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" space-before="{$title-spacing-before}pt" space-after="{$title-spacing-after}pt" keep-with-next.within-page="always">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'italic') then
            <fo:block font-family="{$font-family}" font-style="italic" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" space-after="{$space-after-paragraph}">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'strong') then
            <fo:block font-family="{$font-family}" font-weight="bold" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" space-after="{$space-after-paragraph}">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'flushleft') then
            <fo:block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" space-after="{$space-after-paragraph}">
                {if ($div-id = 'index') then attribute span {"all"} else ()}
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'center') then
            <fo:block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" text-align="center" space-after="{$space-after-paragraph}">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'right') then
            <fo:block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" text-align="right" space-after="{$space-after-paragraph}">
                {t2f:recurse($node, $options)}
            </fo:block>
        
        (: paragraphs inside of notes :)
        else if ($node/parent::tei:note) then
            <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" text-indent="10mm" space-after="3mm">
                {t2f:recurse($node, $options)}
            </fo:block>
        
        (: list of sources old styles: 'sourceparagraphspaceafter', 'sourceparagraphfullindent', 'sourceparagraphtightspacing', 'sourceheadcenterboldbig', 'sourcearchiveboldbig' :)
        else if ($rend = 'sourceparagraphspaceafter') then
            <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" space-after="1em">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'sourceparagraphfullindent') then
            <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" space-after="{$space-after-paragraph}" start-indent="10mm">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'sourceparagraphtightspacing') then
            <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" space-after="{$space-after-paragraph}" line-height="1.1em">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'sourceheadcenterboldbig') then
            <fo:block font-family="{$font-family}" font-size="14pt" font-weight="bold" text-align="center" space-after="3mm" padding="2px">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($rend = 'sourcearchiveboldbig') then
            <fo:block font-family="{$font-family}" font-size="13pt" font-weight="bold" space-after="3mm" start-indent="0mm">
                {t2f:recurse($node, $options)}
            </fo:block>
        else if ($node/parent::tei:quote) then
            <fo:block font-family="{$font-family}" font-size="inherit" space-after="{$quote-paragraph-spacing}pt">
                {if ($node/preceding-sibling::tei:p and not($node/parent::tei:quote/@rend='blockquote-transcript')) then attribute text-indent {'.25in'} else ()}
                {t2f:recurse($node, $options)}
            </fo:block>
        else
            <fo:block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" text-indent="{$paragraph-text-indent}" space-after="{$space-after-paragraph}" text-align="justify" hyphenate="true">
                {t2f:recurse($node, $options)}
            </fo:block>
};

declare function t2f:byline($node as element(tei:byline), $options) as element()* {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := xs:integer($options//param[@name='font-size-normal']/@value)
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $space-below := $font-size-normal
    return
        <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" space-after="{$space-below}pt" font-style="italic">
            {t2f:recurse($node, $options)}
        </fo:block>    
};

declare function t2f:quote($node as element(tei:quote), $options) as element()* {
    let $rend := $node/@rend
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := xs:integer($options//param[@name='font-size-normal']/@value)
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $padding := $font-size-normal div 2
    return 
        if ($rend = ('blockquote', 'blockquote-transcript')) then
            (: make quotes in epigraph larger :)
            if ($node/parent::tei:div/@xml:id = 'epigraph') then 
                <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-indent="0" margin-left="0" margin-right="0" margin-top="{$padding}pt" margin-bottom="{$padding * 2}pt" text-align="justify" hyphenate="true">{t2f:recurse($node, $options)}</fo:block>
            else
                <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" text-indent="0" margin-left="0" margin-right="0" margin-top="{$padding}pt" margin-bottom="{$padding}pt" text-align="justify" hyphenate="true">{t2f:recurse($node, $options)}</fo:block>
        else
            <fo:inline>{t2f:recurse($node, $options)}</fo:inline>
};

declare function t2f:hi($node, $options) as element()* {
    (: schematron recognizes: 'strong', 'italic', 'smallcaps', 'roman', 'underline', 'sub', 'superscript' :)
    let $rend := $node/@rend
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        if ($rend = 'italic') then
            <fo:inline font-style="italic">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'strong') then
            <fo:inline font-weight="bold">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'roman') then
            <fo:inline font-style="normal">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'smallcaps') then
            <fo:inline font-variant="small-caps">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'underline') then
            <fo:inline text-decoration="underline">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'sub') then
            <fo:inline font-size="{$font-size-small}" baseline-shift="sub">{t2f:recurse($node, $options)}</fo:inline>
        else if ($rend = 'superscript') then
            <fo:inline font-size="{$font-size-small}" baseline-shift="super">{t2f:recurse($node, $options)}</fo:inline>
        else 
            t2f:recurse($node, $options)
};

declare function t2f:del($node, $options) as element() {
    (: assume $node/@rend = 'strikethrough' :)
    <fo:inline text-decoration="line-through">{t2f:recurse($node, $options)}</fo:inline>
};

declare function t2f:term($node, $options) as element() {
    <fo:inline>{if ($node/@xml:id) then attribute id {$node/@xml:id} else (), t2f:recurse($node, $options)}</fo:inline>
};

declare function t2f:anchor($node, $options) as element() {
    <fo:inline>{if ($node/@xml:id) then attribute id {$node/@xml:id} else ()}</fo:inline>
};

declare function t2f:figure($node, $options) {
    <fo:block text-align="center" space-before="5mm" space-after="5mm">{t2f:recurse($node, $options)}</fo:block>
};

declare function t2f:graphic($node, $options) {
    let $images-base-collection := '/db/apps/release/resources/images'
    let $filename := 'frus-history' (:frus:volumeid($node):)
    let $images-collection := 
        if (xmldb:collection-available(concat($images-base-collection, '/', $filename))) then
            concat($images-base-collection, '/', $filename) 
        else 
            xmldb:create-collection($images-base-collection, $filename)
    let $url := $node/@url
    let $image-binary-uri := 
        if (doc-available(concat($images-collection, '/', $url, '.svg'))) then
            concat($images-collection, '/', $url, '.svg')
        else if (util:binary-doc-available(concat($images-collection, '/', $url, '.tiff'))) then
            concat($images-collection, '/', $url, '.tiff')
        else if (util:binary-doc-available(concat($images-collection, '/', $url, '.png'))) then
            concat($images-collection, '/', $url, '.png')
        else
            for $ext in ('svg', 'tiff', 'png')
            let $uri := concat($hsg-config:S3_URL || '/', 'frus-history' (:'frus/', $filename :), '/', $url, '.', $ext)
            let $response := httpclient:head(xs:anyURI($uri), false(), ())
            return
                if ($response/@statusCode eq '200') then 
                    let $store := xmldb:store($images-collection, concat($url, '.', $ext), xs:anyURI($uri), concat('image/', if ($ext = 'svg') then 'svg+xml' else $ext))
                    return 
                        concat($images-collection, '/', $url, '.', $ext)
                else 
                    util:log('DEBUG', concat('tei2fo-error: Unable to fetch image ', $url, '.', $ext, ' for volume ', $filename, ' from S3'))
    let $server-path := concat('http://localhost:8080/', substring-after($image-binary-uri[1], '/db/'))
    return
        <fo:external-graphic src="url('{$server-path}')" width="100%" content-width="scale-down-to-fit"/>
};

declare function t2f:lb($node, $options) {
    (: our errata have <lb/> elements to create space between items, but fo:list-block doesn't allow fo:block children, so we'll just suppress these lines for now:)
    if ($node/parent::tei:list) then 
        () 
    else 
        <fo:block space-after="0" space-before="0"/>
    
    (: i originally restricted this to just closers, using the &#160; version for other cases, but this inserted a full blank line... delete this comment when comfortable with this change. :)
    (:if ($node/ancestor::tei:signed or $node/ancestor::tei:p[@rend='right']) then:) 
    (:else
        <fo:block space-after="0" space-before="0">
            &#160;
        </fo:block>:)
};

declare function t2f:pb($node, $options) {
    (:if ($options/param[@name eq 'show-page-images']/@value eq 'yes') then
        <fo:block break-after="page">
            <fo:external-graphic src="url('{$url}')"
                width="100%" content-width="scale-to-fit"
                scaling="uniform"
                content-height="100%" />
        </fo:block>
    else

        <fo:block id="{$node/@xml:id}"/>
        :)
        ()
};

declare function t2f:listBibl($node, $options) as element() {
    <fo:list-block provisional-distance-between-starts=".25in" provisional-label-separation=".1in">
        {
        (:attribute space-after {'6mm'},:)
        if ($node/ancestor::tei:list) then attribute space-before {'2mm'} else () 
        }
        {t2f:recurse($node, $options)}
    </fo:list-block>
};

declare function t2f:bibl($node, $options) as element() {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $is-back-matter := $node/ancestor::tei:back
    return
    <fo:list-item>
        {if ($node/parent::tei:list/ancestor::tei:list) then (:attribute space-before {'2mm'}:) () else ()}
        {if ($node/following-sibling::tei:item) then (:attribute space-after {'2mm'}:) () else ()}
        <fo:list-item-label end-indent="label-end()">
            <fo:block></fo:block>
        </fo:list-item-label>
        <fo:list-item-body>
            {
            attribute start-indent {
                if ($node/ancestor::tei:listBibl) then 
                    'body-start()' 
                else 
                    '.25in'
                },
            attribute text-indent {'-.25in'}
            }
            <fo:block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt">{t2f:recurse($node, $options)}</fo:block>
        </fo:list-item-body>
    </fo:list-item>
};

declare function t2f:list($node, $options) as element() {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $type := $node/ancestor-or-self::tei:list/@type
    let $rend := $node/ancestor-or-self::tei:list/@rend
    let $participant-types := ('participants', 'subject', 'to')
    let $div-id := $node/ancestor::tei:div[1]/@xml:id
    let $is-back-matter := $node/ancestor::tei:back
    return
        <fo:list-block font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt" provisional-distance-between-starts=".25in" provisional-label-separation=".1in">
            { 
            (: override parent paragraph's 1st line indent to prevent spill over into the list and its children :)
            if ($node/parent::tei:p) then attribute text-indent {'0'} else () 
            }
            { 
            (: the list label for bulleted lists should be indented .25in for readability, whether the list is a child or sibling of surrounding paragraphs :)
            attribute margin-left { if ($rend = 'bulleted' and not($is-back-matter)) then '.25in' else '0'} }
            {
            if ($type = $participant-types) then
                attribute space-after {'.125in'}
            else
                if ($node/ancestor::tei:list) then (:attribute space-before {'2mm'}:) () else () 
            }
            {t2f:recurse($node, $options)}
        </fo:list-block>
};

declare function t2f:item($node, $options) as element() {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $participant-types := ('participants', 'subject', 'to')
    let $parent-type := $node/parent::tei:list/@type
    let $parent-rend := $node/parent::tei:list/@rend
    let $ancestor-or-self-type := $node/ancestor::tei:list/@type
    let $div-id := $node/ancestor::tei:div[1]/@xml:id
    let $front-matter-ids := ('persons', 'sources', 'terms', 'index')
    let $is-back-matter := $node/ancestor::tei:back
    return
        <fo:list-item font-family="{$font-family}" font-size="{if ($is-back-matter) then $font-size-small else $font-size-normal}pt">
            {if ($node/parent::tei:list/ancestor::tei:list) then (:attribute space-before {'2mm'}:) () else ()}
            {if ($node/following-sibling::tei:item) then (:attribute space-after {'2mm'}:) () else ()}
            <fo:list-item-label end-indent="label-end()">
                <fo:block>{if ($parent-rend = 'bulleted') then ('•') else ()}</fo:block>
            </fo:list-item-label>
            <fo:list-item-body>
                {
                if ($parent-type = $participant-types) then
                    attribute start-indent {'.5in'}
                else if ($div-id = 'index') then
                    (: force 2nd lines to indent, and first level start flush left; force sub-items to more compact start-indent :)
                    (
                    attribute start-indent {
                        if (count($node/ancestor::tei:list) gt 1) then
                            concat((count($node/ancestor::tei:list) + 1) * .125 , 'in')
                        else if ($node/ancestor::tei:list) then 
                            'body-start()' 
                        else 
                            '.25in'
                        },
                    attribute text-indent {'-.25in'}
                    )
                else if ($div-id = $front-matter-ids or ($is-back-matter and not($parent-rend = 'bulleted'))) then
                    (: force 2nd lines to indent, and first level start flush left :)
                    (
                    attribute start-indent {
                        if ($node/ancestor::tei:list) then 
                            'body-start()' 
                        else 
                            '.25in'
                        },
                    attribute text-indent {'-.25in'}
                    )
                else if ($parent-rend = 'bulleted') then
                    (
                    attribute start-indent {'body-start()'}
                    )
                else 
                    (
                    (:attribute start-indent {'body-start()'},
                    attribute space-before {'2mm'}:)
                    
                    (: force 2nd lines to indent, and first level start flush left :)
                    attribute start-indent {
                        if ($node/ancestor::tei:list) then 
                            'body-start()' 
                        else 
                            '.25in'
                        }(:,
                    attribute text-indent {'-.25in'}:)
                    )
                }
                <fo:block font-family="{$font-family}" font-size="{if ($ancestor-or-self-type = $participant-types) then concat($font-size-small, 'pt') else 'inherit'}" hyphenate="true" text-align="{if ($div-id = 'index') then 'left' else 'justify'}">
                    { if ($node/@xml:id) then attribute id {$node/@xml:id} else () }
                    {t2f:recurse($node, $options)}
                </fo:block>
            </fo:list-item-body>
        </fo:list-item>
};

declare function t2f:ref($node, $options) {
    let $output-type := $options//param[@name='output-type']/@value
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $target := $node/@target
    let $style := 
        if ($output-type = ('print', 'paperback')) then ()
        else 
            (
            attribute text-decoration {'underline'},
            attribute color {'blue'}
            )
    return
        if (starts-with($target, 'frus')) then
            let $tokens := tokenize($target, '#')
            let $url := concat('http://history.state.gov/historicaldocuments/', string-join($tokens, '/'))
            return
                <fo:basic-link external-destination="url('{$url}')">{$style}
                    {t2f:recurse($node, $options)}
                </fo:basic-link>
        else if (starts-with($target, 'http')) then
            <fo:basic-link external-destination="url('{$target}')">{$style}
                {
                (: URLs are long and aren't handled by FOP's hyphenation algorithm, 
                   so we need to supply hints for where the hyphenation engine should 
                   break lines. We use the "zero-width space" character. 
                   See en.wikipedia.org/wiki/Zero-width_space :)
                let $zwsp := '&#8203;'
                let $break-before := replace($node, '([%?])', concat($zwsp, '$1'))
                let $break-after := replace($break-before, '([/\.=&amp;-])', concat('$1', $zwsp))
                return
                    $break-after
                }
            </fo:basic-link>
            (: <ref target="#range(b_446-start,b_446-end)">196–199</ref> :)
        else if (starts-with($target, '#range')) then
            let $range := substring-after($target, '(')
            let $range := substring-before($range, ')')
            let $range := tokenize($range, ',')
            let $range-start := $range[1]
            let $range-end := $range[2]
            return
                if (root($node)/id($range[1]) and root($node)/id($range[2])) then
                    <fo:basic-link internal-destination="{$range-start}"><fo:page-number-citation ref-id="{$range-start}"/>–<fo:page-number-citation ref-id="{$range-end}"/></fo:basic-link>
                else
                    <fo:inline>{$range-start}–{$range-end}</fo:inline>
        else if (starts-with($target, '#b')) then
            let $url := substring-after($target, '#')
            let $target-node := root($node)/id($url)
            let $footnote-suffix := if ($target-node/ancestor::tei:note) then <fo:inline font-style="italic">n</fo:inline> else ()
return
                if ($target-node) then 
                    <fo:basic-link internal-destination="{$url}">{$style}<fo:page-number-citation ref-id="{$url}"/>{$footnote-suffix}</fo:basic-link>
                else 
                    <fo:inline>{$url}</fo:inline>
        else (:if (starts-with($target, '#')) then:)
            let $url := substring-after($target, '#')
            return
                <fo:basic-link internal-destination="{$url}">{$style}
                    {t2f:recurse($node, $options)}
                </fo:basic-link>
};

declare function t2f:note($node, $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $footnote-reference-font-size := $font-size-small - 2
    let $paragraph-text-indent := $options//param[@name='paragraph-text-indent']/@value
    return
    
    (: footnote-body/block/@space-after isn't working
       @start-indent is set to 0 to prevent footnotes hung on list items from getting extra indented, e.g., frus1964-68v04#d3fn2 
       @text-align is set to start to prevent footnotes hung on right-aligned text from getting right aligned, e.g., frus1950-55Intel#d186:)
    if ($node/@rend='inline') then
        (: display inline notes inline :)
        <fo:block font-family="{$font-family}" font-weight="normal" font-size="{$font-size-small}pt" space-after="2mm" start-indent="0" text-align="start">
            {t2f:recurse($node, $options)}
        </fo:block>
    else if ($node/@type='summary') then 
        (: suppress ePub summary notes from being displayed :)
        ()
    else if ($node/@n = '0') then
        <fo:footnote>
            <fo:inline font-family="{$font-family}" font-weight="normal" font-size="{$footnote-reference-font-size}pt" vertical-align="super">Source</fo:inline>
            <fo:footnote-body>
                <fo:block font-family="{$font-family}" font-weight="normal" font-size="{$font-size-small}pt" text-indent="10mm" id="{$node/@xml:id}" space-after="2mm" start-indent="0" text-align="start" text-align="justify">
                    Source: {t2f:recurse($node, $options)}
                </fo:block>
            </fo:footnote-body>
        </fo:footnote>
    else if ($node/@target) then
        (: for doubled footnotes, marked by note/@target , keep the footnote number but drop the footnote content :)
        let $target-note-id := substring-after($node/@target, '#')
        let $note := root($node)/id($target-note-id)
        return
            <fo:footnote>
                <fo:inline font-family="{$font-family}" font-weight="normal" font-size="{$footnote-reference-font-size}pt" vertical-align="super">{$note/@n/string()}</fo:inline>
                <fo:footnote-body>
                    <fo:block/>
                </fo:footnote-body>
            </fo:footnote>
    else if ($node/ancestor::tei:div[1]/@rend = "endnotes") then
        <fo:inline font-family="{$font-family}" font-weight="normal" font-size="{$footnote-reference-font-size}pt" vertical-align="super">{$node/@n/string()}</fo:inline>
    else 
        <fo:footnote>
            <fo:inline font-family="{$font-family}" font-weight="normal" font-size="{$footnote-reference-font-size}pt" baseline-shift="super">{$node/@n/string()}</fo:inline>
                <fo:footnote-body>
                    <fo:block font-size="{$font-size-small}pt" padding-bottom=".125em" margin-left="{if ($node/parent::tei:item/parent::tei:list/parent::tei:p) then 'from-nearest-specified-value(margin-left) * -2' else if ($node/ancestor::tei:list/@rend = 'bulleted') then concat(count($node/ancestor::tei:list) * -.5, 'in') else '0'}" text-indent=".25in" id="{$node/@xml:id}">
                        {$node/@n/string()}. {t2f:recurse($node, $options)}
                    </fo:block>
                </fo:footnote-body>
        </fo:footnote>
};
        (:
        <fo:footnote>
            <fo:inline font-family="{$font-family}" font-weight="normal" font-size="{$footnote-reference-font-size}pt" baseline-shift="super">{$node/@n/string()}</fo:inline>
            <fo:footnote-body>
                <fo:list-block provisional-distance-between-starts=".25in" provisional-label-separation=".1in" padding-bottom=".125em" margin-left="{if ($node/parent::tei:item/parent::tei:list/parent::tei:p) then 'from-nearest-specified-value(margin-left) * -2' else if ($node/ancestor::tei:list/@rend = 'bulleted') then concat(count($node/ancestor::tei:list) * -.5, 'in') else '0'}" text-indent="0" id="{$node/@xml:id}">
                    <fo:list-item>
                        <fo:list-item-label end-indent="label-end()">
                            <fo:block font-family="{$font-family}" font-size="{$footnote-reference-font-size}pt" baseline-shift="super">
                                {$node/@n/string()}
                            </fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()">
                            <fo:block font-family="{$font-family}" font-size="{$font-size-small}pt" font-weight="normal">
                                {t2f:recurse($node, $options)}
                            </fo:block>
                        </fo:list-item-body>
                    </fo:list-item>
                </fo:list-block>
            </fo:footnote-body>
        </fo:footnote>
        :)(: @text-align here was "start" before we applied justification/hyphenation :)

declare function t2f:dateline($node as element(tei:dateline), $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        <fo:block font-family="{$font-family}" text-align="end" space-after="6mm">
            {t2f:recurse($node, $options)}
        </fo:block>
};

declare function t2f:closer($node as element(tei:closer), $options) as element() {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        <fo:block font-family="{$font-family}" font-size="{$font-size-normal}" text-align="end" space-before="1em">
            {t2f:recurse($node, $options)}
        </fo:block>
};

declare function t2f:signed($node as element(tei:signed), $options) as element() {
    <fo:block>
        {t2f:recurse($node, $options)}
    </fo:block>
};

declare function t2f:table($node as element(tei:table), $options) as element()+ {
    (: apache fop doesn't support table-and-caption :)
    (
    if ($node/tei:head) then 
        t2f:main($node/tei:head, $options)
    else ()
    ,
    let $rend := $node/@rend
    return
        <fo:table space-after="2mm" table-layout="fixed" width="100%">
            {if ($rend = 'bordered') then (attribute border {"solid"}, attribute border-collapse {"collapse"}) else ()}
            <fo:table-body start-indent="0pt" text-align="start">
                {t2f:main($node/node()[not(name(.) = 'head')], $options)}
            </fo:table-body>
        </fo:table>
    )
};

declare function t2f:row($node as element(tei:row), $options) as element() {
    let $table-rend := $node/ancestor::tei:table[1]/@rend
    let $role := $node/@role
    return
        <fo:table-row keep-together.within-column="always">
            {if ($role = 'label') then attribute keep-with-next {"always"} else ()}
            {if ($table-rend = 'bordered') then (attribute border {"solid"}, attribute border-collapse {"collapse"}) else ()}
            {t2f:recurse($node, $options)}
        </fo:table-row>
};

declare function t2f:cell($node as element(tei:cell), $options) as element() {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $table-rend := $node/ancestor::tei:table[1]/@rend
    let $columns := $node/@cols
    return
        <fo:table-cell padding="1mm">
            {if ($columns) then attribute number-columns-spanned {$columns} else ()}
            {if ($table-rend = 'bordered') then (attribute border {"solid"}, attribute border-collapse {"collapse"}) else ()}
            {
            if ($node/tei:p) then 
                t2f:main($node, $options) 
            else 
                <fo:block font-size="{$font-size-small}pt">{
                    if ($columns) then attribute text-align {"center"} else (),
                    if ($node/parent::tei:row/@role = "label") then attribute font-weight {'bold'} else (),
                    t2f:recurse($node, $options)
                }</fo:block>
            }
        </fo:table-cell>
};


(: bookmarks :)

declare function t2f:bookmark-passthru($node as item()*) {
    for $node in $node/node()
    return
        typeswitch($node)
            case element(tei:div) return t2f:bookmark-div($node)
            default return t2f:bookmark-passthru($node)
};

declare function t2f:bookmark-div($node as element(tei:div)) {
    (: we only show divs that have @xml:id attributes :)
    if ($node/@xml:id and not($node/@xml:id = $t2f:frus-div-xmlids-to-suppress)) then
        <fo:bookmark internal-destination="{$node/@xml:id}">
            <fo:bookmark-title>
                {t2f:bookmark-head($node/tei:head[1])}
            </fo:bookmark-title>
            {t2f:bookmark-passthru($node)}
        </fo:bookmark>
    else 
        ()
};

declare function t2f:bookmark-head($node as element(tei:head)) {
    if ($node/@type = 'shortened-for-running-head') then () else
    
    let $head-sans-note := functx:remove-elements-deep($node, 'note')
    return
        if ($node/parent::tei:div/@type = 'document') then
            if (matches($node/string(), '^\s*?\d+\.') or matches($node/string(), '^\s*?No\. \d+')) then 
                normalize-space($head-sans-note)
            else
                concat($node/parent::tei:div/@n, '. ', normalize-space($head-sans-note))
        else
            normalize-space($head-sans-note)
};

(: table of contents :)

declare variable $t2f:frus-div-xmlids-to-suppress { ('toc', 'pressrelease', 'summary', 'subseriesvols') };
declare variable $t2f:frus-div-xmlids-to-suppress-from-toc { ('epigraph') };

declare function t2f:toc($content as element(), $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        <fo:block id="contents" font-family="{$font-family}" break-after="page">
            <fo:block font-size="28pt" space-before="5mm" space-after="5mm">Contents</fo:block>
            {t2f:toc-passthru($content, $options)}
        </fo:block>
};

declare function t2f:frus-toc($volume as xs:string, $options) {
    let $vol := frus:volume($volume)
    return
    	t2f:toc($vol, $options)
};

(: volume of just the section id and deeper :)
declare function t2f:toc-inner($volume as xs:string, $id as xs:string?, $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $inner-section := frus:id($volume, $id)
    return
    	<fo:block id="{$id}-contents">
            {t2f:toc-passthru($inner-section, $options)}
        </fo:block>
};

declare function t2f:toc-passthru($node as item()*, $options) {
    for $node in $node/node()
    return
        typeswitch($node)
            case element(tei:div) return t2f:toc-div($node, $options)
            default return t2f:toc-passthru($node, $options)
};

(: handles divs for TOCs :)
declare function t2f:toc-div($node as element(tei:div), $options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $output-type := $options//param[@name='output-type']/@value
    let $link-style := 
        if ($output-type = ('print', 'paperback')) then 
            ()
        else 
            (
            attribute text-decoration {'underline'},
            attribute color {'blue'}
            )
    let $space-before := 
        attribute space-before {
            if ($output-type = ('print', 'paperback')) then 
                '1mm'
            else 
                '3mm'
            }
    return
    (: we only show divs that have @xml:id attributes :)
    if (not($node/@xml:id = $t2f:frus-div-xmlids-to-suppress) and not($node/@xml:id = $t2f:frus-div-xmlids-to-suppress-from-toc) and not($node/@type = 'document')) then
        <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt" text-indent="-.25in" margin-left=".25in" text-align="start" end-indent=".35in" last-line-end-indent="-.35in">
            {
            (: suppress dots and line numbers for certain sections, so prevent justify behavior :)
            if ($node/@type='part') then () else attribute text-align-last {'justify'}
            }
            <fo:basic-link internal-destination="{$node/@xml:id}">{$link-style}
                {t2f:toc-head($node/tei:head[1], $options)}
                {
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
                }
                {'&#160;'}
                {
                if ($node/@type = 'part') then () 
                else 
                    (
                    <fo:leader leader-pattern="dots" leader-pattern-width="4pt" leader-alignment="reference-area"/>
                    ,
                    <fo:page-number-citation ref-id="{$node/@xml:id}"/>
                    )
                }
            </fo:basic-link>
            {
            if ($node/tei:div/@xml:id and $node/tei:div/@type != 'document') then 
                <fo:block font-family="{$font-family}" font-size="{$font-size-normal}pt">
                    {t2f:toc-passthru($node, $options)}
                </fo:block>
            else 
                ()
            }
        </fo:block>
    else 
        ()
};

(: handles heads for TOCs :)
declare function t2f:toc-head($node as element(tei:head), $options) {
    let $head-sans-note := functx:remove-elements-deep($node, 'note')
    return
        t2f:recurse($head-sans-note, $options)
};

declare function t2f:frus-title-page($volume-id) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    let $volumes := collection('/db/apps/frus/bibliography')
    let $volume := $volumes//volume[@id eq $volume-id]
    let $editors := $volume/editor
    let $published-year := $volume/published-year/text()
    let $margin-left := '2in'
    return
        <fo:block id="title" font-family="{$font-family}" break-after="page">
            <fo:block margin-left=".5in" padding-bottom="-.8in"><fo:external-graphic src="url('http://localhost:8080/exist/apps/release/resources/images/dos-seal-bw-2400dpi.tiff')"/></fo:block>
            <fo:block font-size="18pt" font-weight="bold" space-before="5mm" space-after="0mm" margin-left="{$margin-left}">{concat(frus:volume-title($volume-id, 'series'), ', ', frus:volume-title($volume-id, 'subseries'))}</fo:block>
            <fo:block space-before="0mm">
                <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black" />
            </fo:block>
            <fo:block font-size="16pt" font-weight="bold" space-before="5mm" space-after="5mm" margin-left="2in">{frus:volume-title($volume-id, 'volumenumber')}</fo:block>
            <fo:block font-size="28pt" font-weight="bold" space-before="5mm" space-after="{max((25 - (count($editors) - 2) * 6, 10))(: reduce space as editors increase, but keep a minimum space of 10:)}mm" margin-left="2in">{frus:volume-title($volume-id, 'volume')}</fo:block>
            {
            if ($editors) then
                <fo:list-block provisional-distance-between-starts="35mm" provisional-label-separation="5mm" space-after="{max((40 - (count($editors) - 2) * 15, 10))(: reduce space as editors increase, but keep a minimum space of 10:)}mm" margin-left="{$margin-left}">
                    <fo:list-item space-after="3mm">
                        <fo:list-item-label end-indent="50mm">
                            <fo:block font-style="italic" font-size="14pt">{if (count($editors[@role="primary"]) gt 1) then 'Editors' else 'Editor'}</fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()">
                            {
                            for $ed in $editors[@role="primary"] 
                            return 
                                <fo:block font-size="14pt">{$ed/string()}</fo:block>
                            }
                        </fo:list-item-body>
                    </fo:list-item>
                    <fo:list-item>
                        <fo:list-item-label end-indent="label-end()">
                            <fo:block font-style="italic" font-size="14pt">General Editor</fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()">
                            <fo:block font-size="14pt">{$editors[@role="general"]/text()}</fo:block>
                        </fo:list-item-body>
                    </fo:list-item>
                </fo:list-block>
            else ()
            }
            <fo:block>
                <fo:leader leader-pattern="rule" leader-length="100%" rule-thickness="2pt" rule-style="solid" color="black"/>
            </fo:block>
            <fo:block margin-left="{$margin-left}" space-after="0">United States Government Printing Office</fo:block>
            <fo:block margin-left="{$margin-left}">Washington</fo:block>
            <fo:block margin-left="{$margin-left}" space-after="1em">{$published-year}</fo:block>

            <fo:block margin-left="{$margin-left}">U.S. Department of State</fo:block>
            <fo:block margin-left="{$margin-left}">Office of the Historian</fo:block>
            <fo:block margin-left="{$margin-left}" space-after="1em">Bureau of Public Affairs</fo:block>
            
            <fo:block margin-left="{$margin-left}" font-size="10pt" space-after="0">This experimental PDF was generated on {format-date(current-date(), 'MMMM D, YYYY')}. Please visit the Office of the Historian 
                <fo:basic-link external-destination="url('http://history.state.gov/historicaldocuments/{$volume-id}')" text-decoration="underline" color="blue">home 
                page for this volume</fo:basic-link> to access updates.</fo:block>
        </fo:block>
};

declare function t2f:about-the-digital-edition($options) {
    let $font-family := $options//param[@name='font-family']/@value
    let $font-size-normal := $options//param[@name='font-size-normal']/@value
    let $font-size-small := $options//param[@name='font-size-small']/@value
    return
        <fo:block id="about" font-family="{$font-family}" break-after="page">
            <fo:block font-size="28pt" space-before="5mm" space-after="5mm">About the Digital Edition</fo:block>
            <fo:block font-size="{$font-size-normal}pt" text-indent="10mm" space-after="3mm">The Office of the Historian at the U.S. 
                Department of State has embarked on a program to digitize the <fo:inline font-style="italic">Foreign 
                Relations of the United States</fo:inline> (<fo:inline font-style="italic">FRUS</fo:inline>) series
                and make the digital edition available in standard electronic formats, including web, ebook, PDF,
                and raw XML. This PDF edition is enhanced with hyperlinks for all internal and intra-series 
                cross-references and document lists.</fo:block>
            <fo:block font-size="{$font-size-normal}pt" text-indent="10mm" space-after="3mm">This PDF was 
                generated from a digital master file, a Text Encoding Initiative (TEI)-based representation of 
                the original printed edition.  In encoding the TEI master and generating this PDF, the utmost care was taken to maintain 
                fidelity with the original printed edition where possible.  However, because of the 
                the process of generating this PDF, the page numbers that appear in this edition do not correspond 
                to those in the original printed edition. For readers who need to cite material in this PDF, please
                cite document numbers instead of page numbers, since document numbers remain consistent across formats. 
                Also, because indexes in certain older <fo:inline font-style="italic">FRUS</fo:inline> 
                volumes refer to page numbers rather than document numbers, these indexes cannot be used “as is”
                when translated to PDF form and so have been omitted from the PDF edition of pre-Johnson
                administration volumes. Volumes from the Johnson administration onward, whose indexes
                reference document numbers, are unaffected by this issue. </fo:block>
            <fo:block font-size="{$font-size-normal}pt" text-indent="10mm" space-after="3mm">The Office of the Historian has worked 
                to ensure that this PDF is error-free.  Please email 
                <fo:basic-link
                    external-destination="url('mailto:history_ebooks@state.gov?subject=FRUS%20PDF%20Feedback&amp;body=Your%20PDF%20Reader%20Application%3A%0A%0AVolume%3A%0A%0AComments%3A')"
                    text-decoration="underline" color="blue">history_ebooks@state.gov</fo:basic-link> with
                any feedback.</fo:block>
            <fo:block font-size="{$font-size-normal}pt" text-indent="10mm" space-after="3mm">To find updates to this PDF, access other 
                volumes, and learn about our ebook initiative, please visit our <fo:basic-link
                    external-destination="url('http://history.state.gov/historicaldocuments/ebooks')"
                    text-decoration="underline" color="blue">ebooks homepage</fo:basic-link>, and follow us
                on Twitter at <fo:basic-link external-destination="url('http://twitter.com/HistoryAtState')"
                    text-decoration="underline" color="blue">@HistoryAtState</fo:basic-link> and Tumblr at
                    <fo:basic-link external-destination="url('http://HistoryAtState.tumblr.com')"
                    text-decoration="underline" color="blue">HistoryAtState</fo:basic-link>.</fo:block>
            <fo:block text-align="right" font-weight="bold">Office of the Historian</fo:block>
            <fo:block text-align="right">Bureau of Public Affairs</fo:block>
            <fo:block text-align="right">U.S. Department of State</fo:block>
            <fo:block text-align="right">{format-date(current-date(), '[MNn] [Y0001]')}</fo:block>
        </fo:block>
};
