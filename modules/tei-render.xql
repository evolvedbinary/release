xquery version "3.0";

(:~   This module uses XQuery 'typeswitch' to do all of the FRUS TEI-to-HTML
 :      conversion that we previously did with an XSLT stylesheet (frusteidoc2html.xsl).
 :
      and pass TEI fragments to render:render() as
            render:render($teiFragment, $options)
 :      where $options contains parameters and other info in an element like:
            <parameters>
                <param name="volume" value="{$volume}"/>
                <param name="relativeimagepath" value="{$relativeimagepath}"/>
                <param name="abs-site-uri" value="{$abs-site-uri}"/>
            </parameters>
 :
 :      Author: Joe Wicentowski
 :      Version: 1.0 (Mar 6, 2009)
 :)

module namespace render="http://history.state.gov/ns/xquery/tei-render";

import module namespace frusx = "http://history.state.gov/ns/xquery/frus" at "frus.xql";
import module namespace hsg-config = "http://history.state.gov/ns/xquery/config" at '/db/apps/hsg-shell/modules/config.xqm';
import module namespace console="http://exist-db.org/xquery/console";
import module namespace functx = "http://www.functx.com";

(: default namespaces :)
declare default function namespace "http://www.w3.org/2005/xpath-functions";
declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace frus="http://history.state.gov/frus/ns/1.0";

(: a helper function in case no options are passed to the function :)
declare function render:render($content as node()*) as element() {
    render:render($content, ())
};

(: creates a document div for fitting TEI into history.state.gov template :)
declare function render:render($content as node()*, $options as element()*) as element() {
    let $body-options := <parameters xmlns="">{$options/*}<param name="body-mode-for-footnotes" value="true"/></parameters>
    return
        <div class="document">
            {
            render:recurse($content, $body-options),
            render:note-end($content, $options)
            }
        </div>
};

(: just recurses back to render:main() :)
(: DS: live code actually does various stuff here before it recurses :)
declare function render:recurse($content as node()*, $options) as item()* {
    (: use recursion as an opportunity to insert space between adjacent elements that would otherwise be smooshed if indent=no :)
    (: TODO add check for indent status :)
    let $adjacent-nodes := ('hi', 'ref', 'persName', 'placeName', 'date', 'gloss', 'lb', 'del')
    let $nodes := $content/node()
    let $node-count := count($nodes)
    for $node at $n in $nodes
    return
        (
        render:main($node, $options)
        ,
        (: it helps if the adjacent nodes have already had trailing spaces before close tag removed, e.g., find \s+</hi> replace with </hi> :)
        if ($n < $node-count) then
            if ($node instance of element() and $node/name() = $adjacent-nodes and $nodes[$n + 1] instance of element() and $nodes[$n + 1]/name() = $adjacent-nodes) then ' ' (:'&#160;':) else ()
        else ()
        )
};

(: main routine :)
declare function render:main($nodes as node()*, $options) as item()* {
    for $node in $nodes
    return
    (
    (:console:log(util:node-id($node)),:)
    typeswitch($node)
        case text() return $node
        case element(tei:TEI) return render:TEI($node, $options)
        case element(tei:text) return render:text($node, $options)
        case element(tei:front) return render:front($node, $options)
        case element(tei:body) return render:body($node, $options)
        case element(tei:back) return render:back($node, $options)
        case element(tei:div) return render:div($node, $options)
        case element(frus:attachment) return render:frus-attachment($node, $options)
        case element(tei:head) return render:head($node, $options)
        case element(tei:p) return render:p($node, $options)
        case element(tei:q) return render:q($node, $options)
        case element(tei:quote) return render:quote($node, $options)
        case element(tei:hi) return render:hi($node, $options)
        case element(tei:del) return render:del($node, $options)
        case element(tei:list) return render:list($node, $options)
        case element(tei:item) return render:item($node, $options)
        case element(tei:label) return render:label($node, $options)
        case element(tei:postscript) return render:postscript($node, $options)
        case element(tei:ref) return render:ref($node, $options)
        case element(tei:note) return render:note($node, $options)
        case element(tei:dateline) return render:dateline($node, $options)
        case element(tei:date) return render:date($node, $options)
        case element(tei:time) return render:time($node, $options)
        case element(tei:persName) return render:persName($node, $options)
        case element(tei:gloss) return render:gloss($node, $options)
        case element(tei:placeName) return render:placeName($node, $options)
        case element(tei:orgName) return render:orgName($node, $options)
        case element(tei:term) return render:term($node, $options)
        case element(tei:opener) return render:opener($node, $options)
        case element(tei:salute) return render:salute($node, $options)
        case element(tei:closer) return render:closer($node, $options)
        case element(tei:signed) return render:signed($node, $options)
        case element(tei:listBibl) return render:listBibl($node, $options)
        case element(tei:bibl) return render:bibl($node, $options)
        case element(tei:said) return render:said($node, $options)
        case element(tei:listPerson) return render:listPerson($node, $options)
        case element(tei:lb) return render:lb($node, $options)
        case element(tei:milestone) return render:milestone($node, $options)
        case element(tei:anchor) return render:anchor($node, $options)
        case element(tei:figure) return render:figure($node, $options)
        case element(tei:graphic) return render:graphic($node, $options)
        case element(tei:table) return render:table($node, $options)
        case element(tei:row) return render:row($node, $options)
        case element(tei:cell) return render:cell($node, $options)
        case element(tei:geo) return ()
        case element(tei:pb) return render:pb($node, $options)
        case element(tei:title) return render:title($node, $options)
        case element(tei:byline) return render:byline($node, $options)
        case element(tei:seg) return render:seg($node, $options)
        case element(tei:idno) return render:idno($node, $options)
        case element(tei:lg) return render:lg($node, $options)
        case element(tei:l) return render:l($node, $options)

        case element(html:colgroup) return $node

        default return render:recurse($node, $options)
        )
};

declare function render:TEI($node as element(tei:TEI), $options) as element() {
    <div class="tei-TEI">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:text($node as element(tei:text), $options) as element() {
    <div class="tei-text">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:front($node as element(tei:front), $options) as element() {
    <div class="tei-front">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:body($node as element(tei:body), $options) as element() {
    <div class="tei-body">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:back($node as element(tei:back), $options) as element() {
    <div class="tei-back">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:div($node as element(tei:div), $options) {
    if ($node/@type = 'theme-highlight') then
        <div class="searchformcolor">{
            if ($node/@xml:id) then render:xmlid($node, $options) else (),
            render:recurse($node, $options)
        }</div>
    else
        <div>{
            if ($node/@xml:id) then render:xmlid($node, $options) else (),
            render:recurse($node, $options)
        }</div>
};

declare function render:frus-attachment($node as element(frus:attachment), $options) {
    <div>{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        render:recurse($node, $options)
    }</div>
};

declare function render:head($node as element(tei:head), $options) as element()* {
    if ($node/@type = ('shortened-for-running-head')) then
        ()
    else if ($node/parent::tei:div or $node/parent::frus:attachment) then
        let $rendition := $node/@rendition
        let $style := if ($rendition) then attribute style {render:rendition-to-css($rendition)} else ()
        let $type := $node/parent::tei:div/@type
        return
            if ($type = ('section', 'appendix', 'compilation', 'part') ) then
                if ($type eq 'section' and $options/*:param[@name='suppress-head-if-first-div']/@value eq 'true') then ()
                else
                    <h2>{$style, render:recurse($node, $options)}</h2>
            else if ($type = ('document', 'subchapter', 'chapter', 'chapter-introduction', 'part') ) then
                (
                (: show a bracketed document number for volumes that don't use document numbers :)
            	if ($type = 'document' and not(starts-with($node, concat($node/parent::tei:div/@n, '.')) or starts-with($node, concat('No. ', $node/parent::tei:div/@n)))) then
                    <p style="font-size: smaller">{
                        if (matches($node/parent::tei:div/@n, '^\[.+?\]$')) then
                            $node/parent::tei:div/@n/string()
                        else
                            concat('[Document ', $node/parent::tei:div/@n, ']')
                    }</p>
                else (),
                <h3>{$style, render:recurse($node, $options)}</h3>
                )
            else if ($type = 'timeline') then
                <strong>{render:recurse($node, $options)}</strong>
            else if ($node/ancestor::tei:div/@xml:id) then
                element {concat('h', index-of($node/ancestor::tei:div, $node/ancestor::tei:div[@xml:id][1]) + 2)} {$style, render:recurse($node, $options)}
            else
                <h3>{$style, render:recurse($node, $options)}</h3>
    else if ($node/parent::tei:figure) then
        if ($node/parent::tei:figure/parent::tei:p) then
            <strong>{render:recurse($node, $options)}</strong>
        else (: if ($node/parent::tei:figure/parent::tei:div) then :)
            <p><strong>{render:recurse($node, $options)}</strong></p>
    else if ($node/parent::tei:list) then
        if ($node/parent::tei:list/@type = ('participants', 'subject', 'from', 'references', 'to') ) then
            if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
                <p>{render:recurse($node, $options)}</p>
            else
                <li class="subjectallcaps">{render:recurse($node, $options)}</li>
        else if ($node/ancestor::tei:list/@type = ('participants', 'subject', 'from', 'references', 'to') ) then
            if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
                <blockquote class="subjectallcaps">{render:recurse($node, $options)}</blockquote>
            else
                <li class="subjectallcaps">{render:recurse($node, $options)}</li>
        else
            <strong>{render:recurse($node, $options)}</strong>
    else if ($node/parent::tei:table) then
        <p class="center">{render:recurse($node, $options)}</p>
    else
        <span class="tei-head">{render:recurse($node, $options)}</span>
};

(: TODO: Look for instances in the XML of the weird old 'participantcol129' :)
declare function render:p($node as element(tei:p), $options) as item()* {
    let $rend := $node/@rend
    let $body-mode-for-footnotes := $options/*:param[@name='body-mode-for-footnotes']/@value
    let $result :=
        if ($rend) then
            if ($rend = (
                        'subjectentry', 'sectiontitleital', 'sectiontitlebold', 'subjectallcaps',
                        'sourceheadcenterboldbig', 'sourcearchiveboldbig', 'sourceparagraphspaceafter',
                        'sourceparagraphtightspacing', 'sourceparagraphfullindent',
                        'flushleft', 'right', 'center', 'strong', 'centerstrong')
                        ) then
                <p>{ attribute class {data($rend)} }{ render:recurse($node, $options) }</p>
            else if ($rend = 'italic') then
                <p><em>{render:recurse($node, $options)}</em></p>
            else if ($rend = 'underline') then
                <p><span style="text-decoration: underline">{render:recurse($node, $options)}</span></p>
            else
                <p>{render:recurse($node, $options)}</p>
            (: TODO: Try to handle multi-paragraph footnotes for Forrest
            else if ($node/parent::tei:note and not($node/preceding-sibling::tei:p)) then
                render:recurse($node, $options)
                :)
        else
            <p>{render:recurse($node, $options)}</p>
    return

        (: check if we're inside the body version of a footnote, rather than the render:note-end() version.
        if so, collapse the block <p> into an inline <span> to prevent artifacts of the note from appearing in
        the surrounding paragraph text :)

        if ($body-mode-for-footnotes = 'true' and $node/ancestor::tei:note[1][not(@rend = 'inline')]) then
            if ($node/preceding-sibling::element()) then
                (<br/>, <br/>, <span>{$result/@*, $result/node()}</span>)
            else
                $result/node()

        (: if we're just a normal paragraph, then carry on :)

        else
            $result

};

declare function render:q($node as element(tei:q), $options) as element()* {
    let $rend := $node/@rend
    return
        if ($rend = 'blockquote') then
            if ($node/tei:p) then
                <blockquote>{render:recurse($node, $options)}</blockquote>
            else
                <blockquote><p>{render:recurse($node, $options)}</p></blockquote>
        else if ($node/parent::tei:q) then
            <span class="single-quoted">‘{render:recurse($node, $options)}’</span>
        else
            <span class="double-quoted">“{render:recurse($node, $options)}”</span>
};

declare function render:quote($node as element(tei:quote), $options) as element()* {
    let $rend := $node/@rend
    return
        (: if ($rend = 'blockquote') then :)
            if ($node/tei:p or $node/tei:lg) then
                <blockquote>{render:recurse($node, $options)}</blockquote>
            else
                <blockquote><p>{render:recurse($node, $options)}</p></blockquote>
        (: else
            <span>{render:recurse($node, $options)}</span> :)
};
(: known types: italic, strong :)
declare function render:hi($node as element(tei:hi), $options) as element() {
    let $rend := $node/@rend
    return
        if ($rend = 'italic') then
            if ($node/ancestor::tei:signed) then
                <em style="font-weight: inherit">{render:recurse($node, $options)}</em>
            else
                <em>{render:recurse($node, $options)}</em>
        else if ($rend = 'strong') then
            <strong>{render:recurse($node, $options)}</strong>
        else if ($rend = 'sub') then
            <sub>{render:recurse($node, $options)}</sub>
        else if ($rend = 'superscript') then
            <sup>{render:recurse($node, $options)}</sup>
        else if ($rend = 'underline') then
            <span style="text-decoration: underline">{render:recurse($node, $options)}</span>
        else if ($rend = 'smallcaps') then
            <span style="font-variant: small-caps">{render:recurse($node, $options)}</span>
        else if ($rend = 'roman') then
            <span style="font-style: normal">{render:recurse($node, $options)}</span>
        else
            <span class="tei-hi{if ($rend) then concat('-@rend-', $rend) else ()}">{render:recurse($node, $options)}</span>
};

declare function render:del($node as element(tei:del), $options) as element() {
	let $rend := $node/@rend
	return
		if ($rend = 'strikethrough') then
			<span class="strikethrough">{render:recurse($node, $options)}</span>
		else
			<span class="tei-del">{render:recurse($node, $options)}</span>
};

declare function render:list($node as element(tei:list), $options) as item()+ {
    if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
        render:recurse($node, $options)
    else
        let $type := $node/@type
        let $rend := $node/@rend
        (: when showing inline footnotes, we have to force block elements like item to be inline :)
        let $force-block-inline := $options/*:param[@name='force-block-inline']/@value
        return
            if ($force-block-inline) then
                (<br/>, render:recurse($node, $options), <br/>)
            else if ($type = ('participants', 'subject', 'from', 'to', 'references', 'simple') ) then
                <ul class="subject">{render:recurse($node, $options)}</ul>
            else if ($type = 'index') then
                <ul class="index">{render:recurse($node, $options)}</ul>
            else if ($type = 'indexentry') then
                <ul class='indexentry'>{render:recurse($node, $options)}</ul>
            else if ($type = 'ordered') then (: TODO fix list/label and list/item :)
                <dl class="customorder">{render:recurse($node, $options)}</dl>
            else if ($rend = 'bulleted') then
                <ul style="list-style-type: disc; padding-left: 1em">{render:recurse($node, $options)}</ul>
            else if ($node/tei:head) then
                (
                if ($node/tei:head) then render:head($node/tei:head, $options) else ()
                ,
                <ul>{for $item in $node/tei:head/following-sibling::* return render:main($item, $options)}</ul>
                )
            else
                <ul>{
                    if ($node/ancestor::tei:list or $node/ancestor::tei:table/@rend='schedule') then () else attribute class {"hanging-indent"},
                    render:recurse($node, $options)
                }</ul>
};

declare function render:item($node as element(tei:item), $options) as element()+ {
    if ($options/*:param[@name='ebook-format']/@value = 'mobi') then
        <blockquote>{
            if ($node/@xml:id) then render:xmlid($node, $options) else (),
            if ($node/preceding-sibling::tei:label) then
                (
                render:recurse($node/preceding-sibling::tei:label[1], $options),
                ' ',
                render:recurse($node, $options)
                )
            else
                render:recurse($node, $options)
        }</blockquote>
    else
        let $force-block-inline := $options/*:param[@name='force-block-inline']/@value
        return
            if ($force-block-inline) then
                (
                <span>{
                    if ($node/parent::tei:list/@rend='bulleted') then
                        '• '
                    else if ($node/preceding-sibling::*[1]/self::tei:label) then
                        concat($node/preceding-sibling::*[1]/self::tei:label, ' ')
                    else
                        ()
                    ,
                    render:recurse($node, $options)
                }</span>,
                <br/>
                )
            else if ($node/preceding-sibling::tei:label) then
                <li>{
                    render:recurse($node/preceding-sibling::tei:label[1], $options), ' ', render:recurse($node, $options)
                }</li>
            else if ($node/parent::tei:list/@type eq 'subject' and $node/parent::tei:list/@rend eq 'flushleft') then
                (: handles flush left subject lines in 1952-54 volumes, TODO - test when receive first volume :)
                <li class="subjectflushleft">{
                    if ($node/@xml:id) then render:xmlid($node, $options) else (),
                    if ($node/preceding-sibling::tei:label) then
                        (
                        render:recurse($node/preceding-sibling::tei:label[1], $options),
                        ' ',
                        render:recurse($node, $options)
                        )
                    else
                        render:recurse($node, $options)
                }</li>
            else
                <li>{
                    if ($node/@xml:id) then render:xmlid($node, $options) else (),
                    if ($node/preceding-sibling::element()[1]/self::tei:label) then
                        (
                        render:recurse($node/preceding-sibling::tei:label[1], $options),
                        ' ',
                        render:recurse($node, $options)
                        )
                    else
                        render:recurse($node, $options)
                }</li>
};

declare function render:label($node as element(tei:label), $options) as item()* {
    if ($node/parent::tei:list) then
        ()
    else
        <span class="tei-label" style="display: block-inline">{render:recurse($node, $options)}</span>
};

declare function render:postscript($node as element(tei:postscript), $options) as element()+ {
    <div class="tei-postscript">{
        if ($node/@xml:id) then render:xmlid($node, $options) else (),
        if ($node/node()[1]/self::tei:label and $node/node()[2]/self::tei:p) then
            let $new-node :=
                (
                element tei:p { $node/tei:label[1], ' ', $node/tei:p[1]/node() }
                ,
                $node/tei:p[1]/following-sibling::node()
                )
            return
                render:main($new-node, $options)
        else
            render:recurse($node, $options)
    }</div>
};

declare function render:xmlid($node as element(), $options) as element() {
    <a id="{$node/@xml:id}"/>
};

declare function local:index-of($seq as node()*, $n as node()) as xs:integer* {
    local:index-of($seq, $n, 1)
};

declare function local:index-of($seq as node()*, $n as node(), $i as xs:integer) as xs:integer* {
    if ( empty($seq) ) then
        ()
    else if ( $seq[1] is $n ) then
        ( $i, local:index-of(remove($seq, 1), $n, $i + 1) )
    else
        local:index-of(remove($seq, 1), $n, $i + 1)
};

(: TODO Add handling for <note place="margin"> :)
declare function render:note($node as element(tei:note), $options ) as item()* {
    let $suppress-note := $options/*:param[@name='suppress-note']/@value
    let $rendition := $node/@rendition
    let $css := if ($rendition) then render:rendition-to-css($rendition) else ()
    return
        if ($suppress-note eq 'true') then
            ()
        else
            let $div := $node/ancestor::tei:div[1]/@xml:id
            return
                if (empty($node) or $node = '') then
                    <sup>
                        {data($node/@n)}
                    </sup>
                else if ($node/@rend='inline') then
                    (: display inline notes inline :)
                    <p>{
                        if ($css) then attribute style { $css } else (),
                        if ($node/@xml:id) then render:xmlid($node, $options) else (),
                        render:recurse($node, $options)
                    }</p>
                else if ($node/@type='summary') then
                    (: suppress ePub summary notes from being displayed :)
                    ()
                else if ($node/@n = '0') then
                    <a href="{concat('#', $div, 'fn', '-source')}" id="{concat($div, 'fnref', '-source')}" class="footnote">
                        <sup>Source</sup>
                        {''(: NOTE removed for EPUB
                        <span class="footnoteinline">
                            {render:recurse($node, element {QName('', 'parameters')} {$options/*, element param {attribute name {'strip-links'}, attribute value {'true'}}})}
                        </span>
                        :)}
                    </a>
                else if (not($node/@xml:id) and $node/@target) then
                    (: handle case of multiple references to the same footnote - TODO generate correct @href :)
                    <a href="#" class="footnote">
                        <sup>
                            {data($node/@n)}
                        </sup>
                    </a>
                else
                    let $incr :=
                        xs:integer(local:index-of($node/ancestor::tei:div[1]//tei:note[@n], $node))
                    let $incr :=
                        if ($node/preceding::tei:note[@n = '0']) then $incr - 1
                        else $incr
                    return
                    <a href="{concat('#', $div, 'fn', $incr)}" id="{concat($div, 'fnref', $incr)}"><sup>{data($node/@n)}</sup>{''
                        (: NOTE removed for EPUB
                        <span class="footnoteinline">
                            {data($node/@n)}.&#160;{data($node) (: TODO find a way to use render:recurse()
                                that doesn't make the CSS hiccup on span/a/em. Until then we lose styling on
                                inline footnotes :)}
                        </span>
                        :)}</a>
        , ' ' (: this trailing space is needed until whitespace issues are fully dealt with :)
};

declare function render:note-end($content, $options) as element()* {
    if (exists($content//tei:note[@n])) then
        (
        <hr class="space"/>,
        <div class="footnotes">
            {
            for $note at $incr in $content//tei:note[@n]
            let $div := $note/ancestor::tei:div[1]/@xml:id
            return
                if ($note/@type = 'summary' or empty($note) or $note = '') then
                    (: suppress ePub summary notes from being displayed :)
                    ()
                else
                    <div>{
                        let $return-link :=
                            (
                            if ($note/@n = '0') then
                                <a href="{concat('#', $div, 'fnref', '-source')}" id="{concat($div, 'fn', '-source')}" title="Return to text" class="source-note">
                                    <sup>*</sup>
                                </a>
                            else
                                let $incr := if ($note/preceding::tei:note[@n = '0']) then $incr - 1 else $incr
                                return
                                    <a href="{concat('#', $div, 'fnref', $incr)}" id="{concat($div, 'fn', $incr)}" title="Return to text" class="footnote" style="display: inline">
                                        <sup>
                                            {data($note/@n)}
                                        </sup>
                                    </a>
                            ,
                            <span>&#160;</span>
                            )
                        let $content-nodes := render:recurse($note, $options)
                        return
                            (: if the 1st child node of the note is a block-level element (e.g., p), we'll get an
                            unwanted space between the footnote number and the beginning of the text. so we check
                            for the first child being an element, and if so, tuck the footnote number inside.
                            TODO: refine this check to operate only on block-level elements. it's currently operating
                            even on phrase-level elements (e.g., em) :)
                            if ($content-nodes[1] instance of element()) then
                                for $content-node at $count in $content-nodes
                                return
                                    if ($count = 1 and $content-node instance of element()) then
                                        element {$content-node/name()} {$content-node/@*, $return-link, $content-node/node()}
                                    else if ($count = 1) then
                                        ($return-link, $content-node)
                                    else
                                        $content-node
                            else
                                ($return-link, $content-nodes)
                    }</div>
            }
        </div>
        )
    else ()
};

declare function render:ref($node as element(tei:ref), $options) as item()* {
    let $target := $node/@target
    let $volume := $options/*:param[@name = 'volume']/@value
    let $abs-site-uri := $options/*:param[@name = 'abs-site-uri']/@value
    let $relativeimagepath := $options/*:param[@name = 'relativeimagepath']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $persistent-view := if ($show-annotations) then '?view=annotations' else ()
    (:let $log := console:log(serialize($node) || ' from ' || $node/ancestor::tei:div[1]/@xml:id):)
    let $type :=
        (: added to support class='mini-doc' for theme doc links :)
        if ($node/@type) then attribute class { $node/@type } else ()
    return
        (: catch refs without text :)
        if ($node eq '') then
            let $newnode := element tei:ref { attribute target {$node/@target}, data($node/@target) }
            return
                render:ref($newnode, $options)
        (: route external links through disclaimer :)
        else if (starts-with($target, 'http')) then
        	(: is it in state.gov domain? :)
            (:if (matches($target, '^https?://[^.]*?.state.gov')) then:)
            	element a {
                    attribute href { $target },
                    attribute title { $target },
                    $type,
                    render:recurse($node, $options)
                }
            (: otherwise show disclaimer :)
            (:else
            	element a {
                    attribute href { concat('/redirect?url=', xmldb:encode($target)) },
                    attribute title { $target },
                    $type,
                    render:recurse($node, $options)
                    }:)
        (: ref to a target in the same volume by the object's @xml:id :)
        else if (starts-with($target, '#')) then
            (: don't let bad links through, but let range links through, which need to be parsed further :)
            if (not(root($node)/id(substring-after($target, '#')) or starts-with($target, '#range'))) then
                render:recurse($node, $options)
            else
                (: cross-ref to a target in the index :)
                if (starts-with($target, '#in')) then
                    element a {
                        attribute href { concat('index.html', $target) },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a document :)
                else if (matches($target, '^#d\d+$')) then
                    element a {
                        attribute href { concat( substring-after($target, '#'), '.html') },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a portion of a document, e.g., footnote :)
                else if (matches($target, '^#d\d+.+')) then
                    element a {
                        attribute href { concat( replace($target, '^#(d\d+)(.+)$', '$1'), '.html', $target) },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a portion of a chapter, e.g., footnote :)
                else if (matches($target, '^#chapter-\d+.*$')) then
                    element a {
                        attribute href {
                            if (contains($target, 'fn')) then
                                let $ch := substring-before(substring-after($target, '#'), 'fn')
                                let $fn := substring-after($target, 'fn')
                                return
                                    concat($ch, '.html#fn', $fn)
                            else
                                replace($target, '^#(chapter-\d+)(.*)$', '$1.html')
                        },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a portion of a chapter, e.g., footnote :)
                else if (matches($target, '^#appendix-[a-z].*$')) then
                    element a {
                        attribute href {
                            if (contains($target, 'fn')) then
                                let $ch := substring-before(substring-after($target, '#'), 'fn')
                                let $fn := substring-after($target, 'fn')
                                return
                                    concat($ch, '.html#', $ch, 'fn', $fn)
                            else
                                replace($target, '^#(appendix-[a-z])(.*)$', '$1.html')
                        },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a portion of a conclusion, e.g., footnote :)
                else if (matches($target, '^#conclusion.*$')) then
                    element a {
                        attribute href {
                            if (contains($target, 'fn')) then
                                let $ch := substring-before(substring-after($target, '#'), 'fn')
                                let $fn := substring-after($target, 'fn')
                                return
                                    concat($ch, '.html#fn', $fn)
                            else
                                replace($target, '^#(conclusion)(.*)$', '$1.html')
                        },
                        $type,
                        render:recurse($node, $options)
                        }
                (: ref to a portion of a introduction, e.g., footnote :)
                else if (matches($target, '^#introduction[a-z].*$')) then
                    element a {
                        attribute href {
                            if (contains($target, 'fn')) then
                                let $ch := substring-before(substring-after($target, '#'), 'fn')
                                let $fn := substring-after($target, 'fn')
                                return
                                    concat($ch, '.html#fn', $fn)
                            else
                                replace($target, '^#(introduction)(.*)$', '$1.html')
                        },
                        $type,
                        render:recurse($node, $options)
                        }
                (: Turn page-based links into document-based links :)
                else if (starts-with($target, '#pg')) then
                    if (
                        let $first-node := $node/preceding-sibling::node()[1]
                        let $second-node := $node/preceding-sibling::node()[2]
                        return
                            $first-node eq '–' and $second-node instance of element(tei:ref) and $second-node[starts-with(@target, '#pg')]
                        )
                        then
                        (
                        (:util:log-system-out(concat('pb rule 1: ', $node/@target)),:)
                        render:recurse($node, $options),
                        ' ',
                        render:pb-range-to-document-links(root($node), substring-after($node/preceding-sibling::tei:ref[1]/@target, '#'), substring-after($target, '#'))
                        )
                    else if (subsequence($node/following-sibling::node(), 1, 1) eq '–' and subsequence($node/following-sibling::node(), 2, 1)/./self::tei:ref[starts-with(@target, '#pg')]) then
                        (
                        (:util:log-system-out(concat('pb rule 2: ', $node/@target)),:)
                        render:recurse($node, $options)
                        )
                    else
                        (
                        (:util:log-system-out(concat('pb rule 3: ', $node/@target)),:)
                        render:recurse($node, $options),
                        ' ',
                        render:pb-to-document-links(root($node), substring-after($target, '#'))
                        )
                (: handle xpointer-style range references, as found in the frus-history, e.g.,
                    index entries like:
                        <term>Washington, George</term>, <ref target="#range(b_37-start,b_37-end)">9–10</ref>
                    point to:
                        <anchor xml:id="b_37-start" corresp="#b_37-end"/>
                    and:
                        <anchor xml:id="b_37-end" corresp="#b_37-start"/>
                :)
                else if (starts-with($target, '#range')) then
                    let $range := substring-after($target, '(')
                    let $range := substring-before($range, ')')
                    let $range := tokenize($range, ',')
                    let $range-start := $range[1]
                    let $range-end := $range[2]
                    let $target-start-node := root($node)/id($range-start)
                    let $target-end-node := root($node)/id($range-end)
                    (: use ancestor notes to ensure linkability :)
                    let $target-start-node := if ($target-start-node/ancestor::tei:note) then $target-start-node/ancestor::tei:note else $target-start-node
                    let $target-end-node := if ($target-end-node/ancestor::tei:note) then $target-end-node/ancestor::tei:note else $target-end-node
                    let $target-start-node-ancestor-div := $target-start-node/ancestor::tei:div[1]
                    let $target-end-node-ancestor-div := $target-end-node/ancestor::tei:div[1]
                    let $same-ancestor-divs := $target-start-node-ancestor-div = $target-end-node-ancestor-div
                    (: use the ancestor chapter div's heading, e.g., "Chapter 9: ...", but chop off at the colon :)
                    let $target-nodes := ($target-start-node, $target-end-node)
                    let $target-divs := ($target-start-node-ancestor-div, $target-end-node-ancestor-div)
                    let $target-node-labels :=
                        let $both-notes := $target-nodes[1]/self::tei:note and $target-nodes[2]/self::tei:note
                        let $one-note := $target-nodes[1]/self::tei:note or $target-nodes[2]/self::tei:note
                        for $target-node at $n in $target-nodes
                        let $ancestor-div-label :=
                            if ($same-ancestor-divs and $n = 2) then
                                ()
                            else
                                string-join(functx:remove-elements-deep($target-divs[$n]/tei:head[1], 'note'), '')
                        let $ancestor-div-label :=
                            if (contains($ancestor-div-label, ':')) then substring-before($ancestor-div-label, ':') else $ancestor-div-label
                        let $node-label :=
                            if ($target-node/self::tei:note) then
                                concat(if ($n = 1 and $both-notes) then 'footnotes ' else 'footnote ', $target-node/@n)
                            else
                                (: paragraph-like-block-number :)
                                concat(if ($one-note) then 'para ' else if ($n = 1) then 'paras ' else '', index-of($target-start-node-ancestor-div/*[not(self::tei:head)][not(self::tei:byline)][not(self::tei:p[@rend='sectiontitlebold'])], $target-node/ancestor::element()[parent::tei:div][1]))
                        return
                            string-join(($ancestor-div-label, $node-label), ' ')
                    let $label :=
                        replace(string-join($target-node-labels, '–'), 'Chapter', 'Ch.')
                    let $target-node-destination-hash :=
                        if ($target-start-node/self::tei:note) then
                            concat('#fnref', substring-after($target-start-node/@xml:id, 'fn'))
                        else
                            concat('#', $range-start)
                    return
                        (: check to make sure the targets exist :)
                        if ($target-start-node and $target-end-node) then
                            element a {
                                attribute href { concat($target-start-node-ancestor-div/@xml:id, '.html', $target-node-destination-hash) },
                                $label
                                }
                        (: display the label in case of malformed links :)
                        else
                            $label
                (: handle single point references, as found in the frus-history, e.g.,
                    index entries like:
                     <term>Woodford, Stewart</term>, <ref target="#b_803">98</ref>
                    point to:
                     <anchor xml:id="b_611"/>
                :)
                else if (starts-with($target, '#b')) then
                    let $url := substring-after($target, '#')
                    let $target-node := root($node)/id($url)
                    let $target-node := if ($target-node/ancestor::tei:note) then $target-node/ancestor::tei:note else $target-node
                    let $destination-div := $target-node/ancestor::tei:div[1]
                    (: use the ancestor chapter div's heading, e.g., "Chapter 9: ...", but chop off at the colon :)
                    let $head := string-join(functx:remove-elements-deep($destination-div/tei:head[1], 'note'), '')
                    let $target-node-label :=
                        if ($target-node/self::tei:note) then
                            concat('footnote ', $target-node/@n)
                        else
                            concat('para ', index-of($destination-div/*[not(self::tei:head)][not(self::tei:byline)][not(self::tei:p[@rend='sectiontitlebold'])], $target-node/ancestor::element()[parent::tei:div][1]))
                    let $label := replace(concat(if (contains($head, ':')) then substring-before($head, ':') else $head, ' ', $target-node-label), 'Chapter', 'Ch.')
                    let $target-node-destination-hash :=
                        if ($target-node/self::tei:note) then
                            concat('#fnref', substring-after($target-node/@xml:id, 'fn'))
                        else
                            $target
                    return
                        if ($target-node) then
                            element a {
                                attribute href { concat($destination-div/@xml:id, '.html', $target-node-destination-hash) },
                                $label
                                }
                        (: display the label in case of malformed links :)
                        else
                            $label
                (: ref to an appendix :)
                else
                    element a {
                        attribute href { concat( substring-after($target, '#'), '.html' ) },
                        $type,
                        render:recurse($node, $options)
                        }
        (: ref to a footnote in another volume :)
        else if (contains($target, '#') and contains($target, 'fn')) then
            element a {
                attribute href { concat('http://history.state.gov/', $abs-site-uri, substring-before($target, '#'), '/', concat(substring-before(substring-after($target, '#'), 'fn'), '#fn', substring-after($target, 'fn')), $persistent-view) },
                $type,
                render:recurse($node, $options)
                }
        (: ref to a subsection of another volume :)
        else if (contains($target, '#')) then
            element a {
                attribute href { concat('http://history.state.gov/', $abs-site-uri, substring-before($target, '#'), '/', substring-after($target, '#')) },
                $type,
                render:recurse($node, $options)
                }
        (: just a ref to another volume :)
        else if (starts-with($target, 'frus')) then
            element a {
                attribute href { concat('http://history.state.gov/', $abs-site-uri, $target) },
                $type,
                render:recurse($node, $options)
                }
        (: most likely a ref to another section of the website :)
        else
            element a {
                attribute href { $target },
                $type,
                render:recurse($node, $options)
                }
};


declare function render:pb-to-document-links($vol as document-node(), $pb-id as xs:string) {
    render:pb-range-to-document-links($vol, $pb-id, $pb-id)
};

declare function render:pb-range-to-document-links($vol as document-node(), $pb1-id as xs:string, $pb2-id as xs:string) {
    let $pb1 := $vol/id($pb1-id)
    let $pb2 := $vol/id($pb2-id)
    let $range-start := $pb1
    let $range-end := subsequence($pb2/following::tei:pb, 1, 1)
    let $divs := $vol//tei:div[@type=('document', 'section') and @xml:id]
    let $divs-within-range := $divs[. >> $range-start and . << $range-end]/@xml:id
    let $ancestor-document := subsequence($range-start/ancestor::tei:div[@type=('document', 'section') and @xml:id], 1, 1)/@xml:id
    let $doc-ids := distinct-values(($ancestor-document, $divs-within-range)[. ne ''])
    (: allow for possibility of links to non-document portions of a volume :)
    let $doc-ids := if (empty($doc-ids)) then ($pb1/ancestor::tei:div[@xml:id][1]/@xml:id, $pb1/following::tei:div[@xml:id][1]/@xml:id)[1] else $doc-ids
    (: let $log := console:log(concat($pb1-id, '-', $pb2-id, ': ', string-join($doc-ids))) :)
    let $docs-in-frag := for $doc-id in $doc-ids return $vol/id($doc-id)
    let $link :=
        <small>[<i>{
            let $docs-count := count($docs-in-frag)
            return
                if ($docs-count = 1) then
                    (
                    if ($pb1 = $pb2) then
                        concat('Pg. ', $pb1/@n, ' is part of ')
                    else
                        concat('Pgs. ', $pb1/@n, '–', $pb2/@n, ' are part of ')
                    ,
                    <a href="{$docs-in-frag/@xml:id}.html">{
                        for $doc in $docs-in-frag
                        return
                            if ($doc/@type='document') then
                                concat('Doc. ', $doc/@n)
                            else
                                frusx:head-sans-note($doc)
                    }</a>
                    )
                else
                    (: may need to account for this :)
                    (
                    if ($pb1-id = $pb2-id) then
                        concat('Pg. ', $pb1/@n, ' includes portions of ')
                    else
                        concat('Pgs. ', $pb1/@n, '–', $pb2/@n, ' include portions of ')
                    ,
                    for $doc at $count in $docs-in-frag
                    return
                        (
                            <a href="{$doc/@xml:id}.html">{if ($doc/@n ne '') then concat('Doc. ', $doc/@n) else frusx:head-sans-note($doc)}</a>,
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
        }</i>]</small>
    return
        $link
};

declare function render:dateline($node as element(tei:dateline), $options) as element() {
    let $rendition := $node/@rendition
    let $css := if ($rendition) then render:rendition-to-css($rendition) else ()
    return
        if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
            <p class="dateline">{render:recurse($node, $options)}</p>
        else if ($css) then
            <span style="{$css}">{render:recurse($node, $options)}</span>
        else
            <p class="dateline">{render:recurse($node, $options)}</p>
};

declare function render:date($node as element(tei:date), $options) as item()* {
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    return

    if ($show-annotations) then
        <span>
            {
            if ($strip-links) then
                render:recurse($node, $options)
            else
                (
                attribute style {"font-weight: bold; color: #496690"}
                ,
                render:recurse($node, $options)
                ,
                <a class="footnote"><sup>[{if ($node/@*) then string-join(for $att in $node/@* return concat('@', name($att), ': ', $att), ', ') else 'no @!!!'}]</sup></a>
                )
            }
        </span>
    else
        render:recurse($node, $options)
};

declare function render:time($node as element(tei:time), $options) as item() {
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    return

    if ($show-annotations) then
        <span>
            {
            if ($strip-links) then
                render:recurse($node, $options)
            else
                (
                attribute style {"font-weight: bold; color: #496690"}
                ,
                render:recurse($node, $options)
                ,
                <a class="footnote"><sup>[{if ($node/@*) then string-join(for $att in $node/@* return concat('@', name($att), ': ', $att), ', ') else 'no @!!!'}]</sup></a>
                )
            }
        </span>
    else
        render:recurse($node, $options)
};

declare function render:persName($node as element(tei:persName), $options) as item()+ {
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    return

    (
    if ($node/@xml:id) then render:xmlid($node, $options) else (),
    if ($show-annotations) then
        let $person-id := substring-after($node/@corresp, '#')
        let $person-entry := root($node)/id($person-id)
        let $name := string($person-entry)
        let $entry := render:main($person-entry/ancestor::tei:item[1]/tei:hi[1]/following-sibling::node(), ())
        return
            if ($person-id) then
                <span>
                    {
                    if ($strip-links) then
                        render:recurse($node, $options)
                    else
                        (
                        attribute style {"font-weight: bold; color: #911625"}
                        ,
                        render:recurse($node, $options)
                        ,
                        <a class="footnote"><sup>{$name}</sup><span class="footnoteinline">{$entry}</span></a>
                        )
                    }
                </span>
            else if ($node/@xml:id) then
                <span>
                    {
                    if ($strip-links) then
                        render:recurse($node, $options)
                    else
                        (
                        attribute style {"font-weight: bold; color: #911625"}
                        ,
                        render:recurse($node, $options)
                        ,
                        <a class="footnote"><sup>[@xml:id: {$node/@xml:id/string()}]</sup></a>
                        )
                    }
                </span>
            else
                <span>
                    {
                    if ($strip-links) then
                        render:recurse($node, $options)
                    else
                        (
                        attribute style {"font-weight: bold; color: #911625"}
                        ,
                        render:recurse($node, $options)
                        ,
                        <a class="footnote"><sup>[no ID!!!]</sup></a>
                        )
                    }
                </span>
    else
        render:recurse($node, $options)
    )
};

declare function render:gloss($node as element(tei:gloss), $options) as item()+ {
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    return

    if ($show-annotations) then
        let $term-id := substring-after($node/@target, '#')
        let $term-entry := root($node)/id($term-id)
        let $term := string($term-entry)
        let $entry := string($term-entry/ancestor::tei:item[1]/tei:hi[1]/following-sibling::node())
        return
            if ($term-id) then
                <span>
                    {
                    if ($strip-links) then
                        render:recurse($node, $options)
                    else
                        (
                        attribute style {"font-weight: bold; color: #496690"}
                        ,
                        render:recurse($node, $options)
                        ,
                        <a class="footnote"><sup>{$term}</sup><span class="footnoteinline">{$entry}</span></a>
                        )
                    }
                </span>
            else
                <span>
                    {
                    if ($strip-links) then
                        render:recurse($node, $options)
                    else
                        (
                        attribute style {"font-weight: bold; color: #496690"}
                        ,
                        render:recurse($node, $options)
                        ,
                        <a class="footnote"><sup>[no ID!!!]</sup></a>
                        )
                    }
                </span>
    else
        render:recurse($node, $options)
};

declare function render:orgName($node as element(tei:orgName), $options) as item()+ {
    if ($node/@xml:id) then render:xmlid($node, $options) else (),
    render:recurse($node, $options)
};

declare function render:placeName($node as element(tei:placeName), $options) as item()+ {
    if ($node/@xml:id) then render:xmlid($node, $options) else (),
    render:recurse($node, $options)
};

declare function render:term($node as element(tei:term), $options) as item()+ {
    let $strip-links := $options/*:param[@name = 'strip-links']/@value
    let $show-annotations := $options/*:param[@name = 'show-annotations']/@value = 'true'
    return

    (
    if ($node/@xml:id) then render:xmlid($node, $options) else (),
    if ($show-annotations) then
        if ($node/@xml:id) then
            <span>
                {
                if ($strip-links) then
                    render:recurse($node, $options)
                else
                    (
                    attribute style {"font-weight: bold; color: #496690"}
                    ,
                    render:recurse($node, $options)
                    ,
                    <a class="footnote"><sup>[@xml:id: {$node/@xml:id/string()}]</sup></a>
                    )
                }
            </span>
        else ()
    else
        render:recurse($node, $options)
    )
};

declare function render:opener($node as element(tei:opener), $options) as element()+ {
    (: mobi doesn't use floats and so doesn't need the same extra spacing :)
    if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
        <div class="opener">{render:recurse($node, $options)}</div>
    else
        (
        <div class="opener" style="padding-bottom: 1em">{render:recurse($node, $options)}</div>
        ,
        <hr class="space"/>
        )
};

declare function render:salute($node as element(tei:salute), $options) as element() {
    <p class="salute">{render:recurse($node, $options)}</p>
};

declare function render:closer($node as element(tei:closer), $options) as element() {
    <p class="closer">{render:recurse($node, $options)}</p>
};

declare function render:signed($node as element(tei:signed), $options) as element() {
	<span class="signed">{render:recurse($node, $options)}</span>
};

declare function render:listBibl($node as element(tei:listBibl), $options) as item()+ {
    if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
        render:recurse($node, $options)
    else
        <ul class="bibl">{render:recurse($node, $options)}</ul>
};

declare function render:bibl($node as element(tei:bibl), $options) as element() {
    if ($options/*:param[@name='ebook-format']/@value = 'mobi') then
        <blockquote>{
            if ($node/@xml:id) then render:xmlid($node, $options) else (),
            render:recurse($node, $options)
        }</blockquote>
    else
        <li>{render:recurse($node, $options)}</li>
};

declare function render:said($node as element(tei:said), $options) as element() {
    <p class="said">{data($node/@who)}: {render:recurse($node, $options)}</p>
};

declare function render:lb($node as element(tei:lb), $options) as item()* {
    let $strip-lbs := $options/*:param[@name = 'strip-line-breaks']/@value
    return
        if ($strip-lbs = 'true') then ' ' else <br/>
};

declare function render:listPerson($node as element(tei:listPerson), $options) as element() {
    let $type := $node/@type
    return
        if ($node/tei:person) then
            <ul>{render:recurse($node, $options)}</ul>
        else
            <ul><li>{data($type)}: {render:recurse($node, $options)}</li></ul>
};

declare function render:person($node as element(tei:person), $options) as element() {
    <li>{render:recurse($node, $options)}</li>
};

declare function render:milestone($node, $options) as element() {
    let $class := $node/@rend
    return
        if ($node/@rend eq 'hr') then
            <hr/>
        else if ($node/@rend eq 'centered-asterisks') then
            <p class="center">* * *</p>
        else
            <hr/>
};

declare function render:anchor($node, $options) as element()* {
    if ($node/ancestor::tei:note) then
        ()
    else
        render:xmlid($node, $options)
};

declare function render:figure($node as element(tei:figure), $options) {
    let $class := if ($node/@rend = 'smallfloatinline') then 'image-smallfloatinline' else 'image-wide'
    return
        if ($node/parent::tei:p) then
            <span class="{$class}">{render:recurse($node, $options)}</span>
        else
            (
            (: insert a 'page-break-before' div immediately before image #2+ in the appendix,
               to ensure caption has a chance of staying on the same page image in ebook :)
            if ($node/ancestor::tei:div/@xml:id = 'appendix' and $node/preceding-sibling::tei:figure) then
                <div style="page-break-before:always;"/>
            else
                ()
            ,
            <div class="{$class}">{render:recurse($node, $options)}</div>
            )
};

declare function render:graphic($node as element(tei:graphic), $options) as node()+ {
    let $url := $node/@url
    let $head := $node/following-sibling::tei:head
    let $relativeimagepath := $options/*:param[@name = 'relativeimagepath']/@value
    return
        (
        <img src="{concat($relativeimagepath, $url, '.png')}" alt="{normalize-space($head)}"/>,
        render:recurse($node, $options)
        )
};

declare function render:table($node as element(tei:table), $options) as element() {
    let $rend := $node/@rend
    let $rendition := $node/@rendition
    let $style :=
        string-join(
            (
                if ($rend="bordered") then
                    if ($options/*:param[@name='ebook-format']/@value eq 'mobi') then
                        attribute border {'1'}
                    else
                        attribute style {'border: 1px solid #606060; border-collapse: collapse'}
                else (),
                if (matches($rend, '^width:')) then
                    $rend
                else (),
                if ($rendition) then
                    render:rendition-to-css($rendition) else
                ()
            ),
            '; '
            )
    return
        <table>{
            if ($style) then attribute style {$style} else (),
            (: legacy: allow older table rend styles :)
            if ($rend and not($style)) then
                attribute class {$rend}
            else (),
            render:recurse($node, $options)
        }</table>
};

declare function render:row($node as element(tei:row), $options) as element() {
    let $label := $node/@role[. = 'label']
    return
        <tr>{if ($label) then attribute class {'label'} else ()}{render:recurse($node, $options)}</tr>
};

declare function render:cell($node as element(tei:cell), $options) as element() {
    let $role := $node/@role
    let $rend := $node/@rend
    let $rendition := $node/@rendition
    let $columns := $node/@cols
    let $rows := $node/@rows
    let $is-label := $role eq 'label'
    let $is-brace := $role eq 'brace'
    let $is-num := $role eq 'num'
    let $style :=
        string-join(
            (
            if ($node/ancestor::tei:table/@rend eq 'bordered') then 'border: 1px solid #606060' else ()
            ,
            if (matches($rend, '^width:')) then $rend else ()
            ,
            if (matches($rend, '^padding-')) then $rend else ()
            ,
            (: Virginia suggested left-align column-spanning cells by default :)
            (:
            if ($columns) then 'text-align: center' else ()
            ,
            :)
            if ($is-num) then 'text-align: right' else ()
            ,
            if ($rendition) then render:rendition-to-css($rendition) else ()
            )
            ,
            '; '
            )
    return
        element { if ($is-label) then 'th' else 'td' } {
            if ($style) then attribute style {$style} else ()
            ,
            if ($columns) then attribute colspan {$columns} else ()
            ,
            if ($rows) then attribute rowspan {$rows} else ()
            ,
            if ($is-brace) then
                let $orientation := if ($node = '{') then 'open' else 'close'
                return
                    <img src="images/brace-{$orientation}.png" alt="{$node/string()}" class="brace" style="{concat('height: ', $rows, 'em; width: 14px;')}"/>
            else
                render:recurse($node, $options)
            }
};

declare function render:pb($node as element(tei:pb), $options) as item()* {
    if ($options/*:param[@name = 'show-annotations']/@value = 'true') then
        let $volume := $options/*:param[@name = 'volume']/@value
        let $abs-site-uri := $options/*:param[@name = 'abs-site-uri']/@value
        let $pagenumber := data($node/@n)
        let $facs := data($node/@facs)
        let $fruspageimagerelativepath :=
            if ($frusx:STATIC-FILE-LOCATION eq 'local') then '/historicaldocuments/'
            else if ($frusx:STATIC-FILE-LOCATION eq 'hsg') then 'http://history.state.gov/historicaldocuments/'
            else (: if ($frus:STATIC-FILE-LOCATION eq 's3') then :)
                $hsg-config:S3_URL || '/frus/'
        let $imagepath :=
            if ($frusx:STATIC-FILE-LOCATION = ('local', 'hsg')) then
                concat($fruspageimagerelativepath, $volume, "/media/medium/")
            else (: if ($frus:STATIC-FILE-LOCATION eq 's3') then :)
                concat($fruspageimagerelativepath, $volume, "/medium/")
        return
            (
            <br/>,
            render:xmlid($node, $options)
            ,
            <span class="pagenumber" style="vertical-align: super;
    font-size: smaller;
    line-height: 0em;
    background-color:#DDDDE8;
    border: solid 1px #CCCCCC;
    padding: 1px 3px;
    font-family:arial, helvetica, sans-serif;
    font-weight:bold;
    text-decoration:none">
                {
                if ($facs) then
                    element a {
                    attribute href {concat($imagepath, $facs, '.png')},
                    attribute title {concat('Page ', $pagenumber)},
                    (: attribute class {"thickbox"},
                    attribute rel {"inline"}, :)
                    attribute style {'text-decoration:none'},
                    <img src="/images/mag-glass.gif" height="10px" />,
                    concat('Page ', $pagenumber)
                    }
                else concat('Page ', $pagenumber)
                }
            </span>
            ,
            <br/>
            )
    else if ($node/ancestor::tei:table) then
        () (: TODO add non-<a>-tag-based approach to giving an anchor - somehow get the @id to hang on the previous/next element in the table - otherwise, if a row's cells are broken up by <a>, it resets column widths in browser :)
    else
        (
        (: drop the pb info if we're inside a list, since it throws epubcheck validation errors :)
        if ($node/ancestor::tei:list) then ()
        else
            <span class="tei-pb">{render:xmlid($node, $options)}</span>
        (: show page number info for EPUB: :)
        (:,
        <br/>
        ,
        <span class="tei:pb">
            {if ($node/@xml:id) then render:xmlid($node, $options) else ()}
            <strong>[start of page {$node/@n/string()} in original print volume]</strong>
        </span>
        ,
        <br/>:)
        )
};

declare function render:title($node as element(tei:title), $options) {
    let $level := $node/@level
    return
        if ($level = ('s', 'm')) then
            <em class="tei-title-{$level}">{render:recurse($node, $options)}</em>
        else if ($level eq 'a') then
            (
            '“',
            render:recurse($node, $options),
            '”'
            )
        else
            <span class="tei-title-{$level}">{render:recurse($node, $options)}</span>
};

declare function render:byline($node as element(tei:byline), $options) {
    <p class="author" style="font-weight: bold">by {render:recurse($node, $options)}</p>
};

declare function render:rendition-to-css($rendition as attribute()) {
    let $rendition-ids := tokenize($rendition/string(), '\s+') ! substring-after(., '#')
    let $rendition-definitions :=
        for $id in $rendition-ids
        return
            root($rendition)/id($id)
    return
        string-join($rendition-definitions, ' ')
};

declare function render:seg($node as element(tei:seg), $options) {
    let $rendition := $node/@rendition
    let $rend := $node/@rend
    let $css :=
        string-join(
            (
            if ($rendition) then render:rendition-to-css($rendition) else (),
            if (contains($rend, ':')) then $rend else ()
            ),
            '; '
            )
    return
        (: avoid fancy floats in mobi, but try to keep spacing somewhat under control :)
        if ($options/*:param[@name='ebook-format']/@value eq 'mobi' and $node/ancestor::tei:opener) then
            <p class="tei-seg" style="margin:0; padding:0">{render:recurse($node, $options)}</p>
        else if ($css) then
            <span style="{$css}">{render:recurse($node, $options)}</span>
        else
            <span class="seg">{render:recurse($node, $options)}</span>
};

declare function render:idno($node as element(tei:idno), $options) {
    let $type := $node/@type
    return
        <span class="{$type}">{render:recurse($node, $options)}</span>
};

declare function render:lg($node as element(tei:lg), $options) {
    <div class="line-group" style="padding: .5em 0">{render:recurse($node, $options)}</div>
};

declare function render:l($node as element(tei:l), $options) {
    <div class="line">{render:recurse($node, $options)}</div>
};

(: render:create-toc(): Some additional functions to create the TOC for use in left sidebars :)

(: create the TOC for use by the left sidebar :)
declare function render:create-toc($tei-text, $web-path-to-page-view, $view, $id) as element() {
    <div id="toc" class="bordered">
        <ul>{render:toc-passthru($tei-text, $web-path-to-page-view, $view, $id)}</ul>
    </div>
};

declare function render:toc-passthru($node, $web-path-to-page-view, $view, $id) {
    for $node in $node/node()
    return
        render:toc-dispatch($node, $web-path-to-page-view, $view, $id)
};

(: the central recursive typeswitch function for handling TOCs :)
declare function render:toc-dispatch($node, $web-path-to-page-view, $view, $id) {
    typeswitch($node)
        case element(tei:div) return render:toc-div($node, $web-path-to-page-view, $view, $id)
        case element(tei:head) return render:toc-head($node, $web-path-to-page-view, $view, $id)
        default return render:toc-passthru($node, $web-path-to-page-view, $view, $id)
};

(: handles divs for TOCs :)
declare function render:toc-div($node as element(tei:div), $web-path-to-page-view, $view, $id) {
      (: we only show divs that have @xml:id attributes :)
      if ($node/@xml:id) then
           (: check the $id to see if it was passed the 'show!first!div' parameter,
              in which case we want to highlight the first div, so
              we set $id to the value of the first div's @xml:id attribute :)
           let $id := if ($id eq 'show!first!div') then ($node/ancestor::tei:text//tei:div[@xml:id])[1]/@xml:id else $id
           (: highlight the div if it matches $id :)
           let $highlight := if ($node/@xml:id eq $id or ($node/@xml:id eq 'foreword' and not($id) and $view ne 'about')) then attribute class {'highlight'} else ()
           return
                (: handle funky milestones toc, aka 'accordion' toc :)
                if (contains(util:collection-name($node), 'milestones')) then
                    (: milestones landing page - just show article titles :)
                    if ($view eq 'about') then
                          (: the article titles are the div nodes whose xml:id is 'foreword' :)
                          if ($node/@xml:id eq 'foreword') then
                              <li>
                                  <a href="{concat($web-path-to-page-view, replace(util:document-name($node), '.xml$', ''))}">{$highlight}
                                      {render:toc-passthru($node, $web-path-to-page-view, $view, $id)}
                                  </a>
                              </li>
                          else
                              ()
                    (: interior pages, showing the contents of the period defined in $view :)
                    else
                       let $period := replace(util:document-name($node), '.xml$', '')
                       let $article :=
                            (: suppress 'foreward' from being appended to the URL:)
                            if ($node/@xml:id/string() eq 'foreword') then ()
                            else $node/@xml:id/string()
                       return
                       <li>
                           <a href="{concat($web-path-to-page-view, $period, '/', $article)}">{$highlight}
                               {render:toc-passthru($node, $web-path-to-page-view, $view, $id)}
                           </a>
                       </li>

                (: this is unused code for a collection-wide accordion TOC view,
                   instead of the single-doc accordion TOC view used in the milestones section :)
                (: else
                        if ($node/parent::tei:front) then
                          (: override the highlight so it's just for the current tei doc, not all :)
                          let $highlight := if (not($id) and $view eq replace(util:document-name($node), '.xml$', '')) then attribute class {'highlight'} else ()
                          return
                               <li>
                                   <a href="{concat($web-path-to-page-view, replace(util:document-name($node), '.xml$', ''))}">{$highlight}
                                       {render:toc-recurse($node, $web-path-to-page-view, $view, $id)}
                                   </a>
                                   {
                                   if ($view eq replace(util:document-name($node), '.xml$', '')) then
                                       <ul>
                                           {render:toc-recurse($node/ancestor::tei:text/tei:body, $web-path-to-page-view, $view, $id)}
                                       </ul>
                                   else ()
                                   }
                               </li>
                        (: if the div doesn't contain child divs, just show the single list item :)
                        else
                               <li>
                                   <a href="{concat($web-path-to-page-view, replace(util:document-name($node), '.xml$', ''), '/', $node/@xml:id/string())}">{$highlight}
                                       {render:toc-recurse($node, $web-path-to-page-view, $view, $id)}
                                   </a>
                               </li>
                :)


                (: the top level of our TOC should only contain the top level divs :)
                else if (local-name($node/..) = ('front', 'body', 'back')) then
                    (: if the div contains child divs, nest them into a new list :)
                    if ($node/tei:div[@xml:id]) then
                        <li>
                            <a href="{concat($web-path-to-page-view, $view, '/', $node/@xml:id/string())}">{$highlight}
                                {data($node/tei:head)}
                            </a>
                            {
                            (: only show child items if the parent is selected :)
                            if ($node/@xml:id eq $id or $node/tei:div/@xml:id = $id) then
                                <ul>
                                    {render:toc-passthru($node, $web-path-to-page-view, $view, $id)}
                                </ul>
                            else ()}
                        </li>
                    (: if the div doesn't contain child divs, just show the single list item :)
                    else
                        <li>
                            <a href="{concat($web-path-to-page-view, $view, '/', $node/@xml:id/string())}">{$highlight}
                                {render:toc-passthru($node, $web-path-to-page-view, $view, $id)}
                            </a>
                        </li>
                (: show non-top level divs as leaf-level list items :)
                else
                    <li>
                        <a href="{concat($web-path-to-page-view, $view, '/', $node/@xml:id/string())}">{$highlight}
                            {render:toc-passthru($node, $web-path-to-page-view, $view, $id)}
                        </a>
                    </li>
       (: don't show divs that don't have @xml:id attributes :)
       else ()
};

(: handles heads for TOCs :)
declare function render:toc-head($node as element(tei:head), $web-path-to-page-view, $view, $id) {
       (: only handle heads whose parent is a div :)
       if ($node/parent::tei:div) then
            (: handle funky milestones toc, aka 'accordion' toc :)
            if (contains(util:collection-name($node), 'milestones')) then
                (: milestones landing page should only show the date :)
                if ($view eq 'about') then
                    $node/tei:date/text()
                (: milestones entries should show the full title :)
                else
                    data($node)
            (: don't bother showing the head "again" in the case where its parent div has already shown it :)
            else if ($node/parent::tei:div/child::tei:div/@xml:id) then
                ()
            (: special handling for 'buildings' article head :)
            else if (contains(util:collection-name($node), 'buildings')) then
                    for $x in $node/node()
                    return
                        typeswitch($x)
                            case element(tei:lb) return ': '
                            default return $x
            else
                render:recurse($node, <params><param name="suppress-note" value="true"/></params>)
       (: don't show heads whose parents aren't divs, e.g. graphics and figures :)
       else ()
};

declare function render:exist-match($node, $options) {
    <span class="highlight">{render:recurse($node, $options)}</span>
};
