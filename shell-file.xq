xquery version "3.0";

import module namespace release = "http://history.state.gov/ns/xquery/release" at "modules/release.xql";
import module namespace frus = "http://history.state.gov/ns/xquery/frus" at "modules/frus.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function local:generate-shell($vol-ids) {
    let $volumes := collection('/db/apps/frus/bibliography')/volume[@id = $vol-ids]
    let $shell-files :=
        for $vol in $volumes
        return
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$vol/@id}">
                <teiHeader>
                <fileDesc>
                    <titleStmt>
                       <title type="complete">{normalize-space($vol/*:title[@type='complete'])}</title>
                        <title type="series">{$vol/*:title[@type='series']/string()}</title>
                        <title type="sub-series">{$vol/*:title[@type='sub-series']/string()}</title>
                        <title type="volume-number">{normalize-space($vol/*:title[@type='volume-number'])}</title>
                        <title type="volume">{normalize-space($vol/*:title[@type='volume'])}</title>
                        {
                            if ($vol/*:editor[@role='primary'][. ne '']) then
                                $vol/*:editor[@role='primary'][. ne ''] ! <editor role="{./@role}">{./string()}</editor>
                            else
                                <editor role="primary">???</editor>
                            ,
                            if ($vol/*:editor[@role='general'][. ne '']) then
                                $vol/*:editor[@role='general'][. ne ''] ! <editor role="{./@role}">{./string()}</editor>
                            else
                                <editor role="general">???</editor>
                        }
                    </titleStmt>
                    <publicationStmt>
                        <publisher>United States Government Publishing Office</publisher>
                        <pubPlace>Washington</pubPlace>
                        <date>{($vol/*:published-year[. ne '']/string(), '???')[1]}</date>
                        <idno type="dospubno"></idno>
                        <idno type="isbn-10">{$vol/*:isbn10/string()}</idno>
                        <idno type="isbn-13">{normalize-space($vol/*:isbn13)}</idno>
                        <idno type="frus">{$vol/@id/string()}</idno>
                        <idno type="oclc">{$vol/*:location[@loc='worldcat']/string()}</idno>
                    </publicationStmt>
                    <sourceDesc><p>Released in {($vol/*:published-year[. ne '']/string(), '???')[1]}</p></sourceDesc>
                </fileDesc>
                <revisionDesc>
                    <change>{format-date(current-date(), '[Y]-[M01]-[D01]')}: Created TEI shell</change>
                </revisionDesc>
            </teiHeader>
            <text>
                <front>
                    <titlePage>
                        <docTitle>
                            <titlePart type="series">{$vol/*:title[@type='series']/string()}</titlePart>
                            <titlePart type="subseries">{$vol/*:title[@type='sub-series']/string()}</titlePart>
                            <titlePart type="volumeno">{normalize-space($vol/*:title[@type='volume-number'])}</titlePart>
                            <titlePart type="volumetitle">{$vol/*:title[@type='volume']/string()}</titlePart>
                        </docTitle>
                        <byline>
                            <hi rend="italic">Editor{
                                if (count($vol/*:editor[@role='primary'][. ne '']) gt 1) then 's' else ''
                            }</hi>: {
                                if ($vol/*:editor[@role="primary"][. ne '']) then
                                    ($vol/*:editor[@role="primary"][. ne ''] ! <name>{./string()}</name>)
                                else
                                    <name>???</name>
                            }
                        </byline>
                        <byline>
                            <hi rend="italic">General Editor</hi>: <name>{($vol/*:editor[@role="general"][. ne '']/string(), '???')[1]}</name>
                        </byline>
                        <docImprint>
                            <publisher>United States Government Printing Office</publisher>
                            <pubPlace>Washington</pubPlace>
                            <docDate>{($vol/*:published-year[. ne '']/string(), '???')[1]}</docDate>
                            DEPARTMENT OF STATE O<hi rend="smallcaps">ffice</hi>
                            <hi rend="smallcaps">of</hi>
                            <hi rend="smallcaps">the</hi> H<hi rend="smallcaps">istorian</hi> B<hi
                                rend="smallcaps">ureau</hi>
                            <hi rend="smallcaps">of</hi> P<hi rend="smallcaps">ublic</hi> A<hi
                                rend="smallcaps">ffairs</hi> For sale by the Superintendent of Documents,
                            U.S. Government Publishing Office Internet: bookstore.gpo.gov Phone: toll free
                            (866) 512-1800; DC area (202) 512-1800 Fax: (202) 512-2250 Mail: Stop IDCC,
                            Washington, DC 20402-0001</docImprint>
                    </titlePage>
                    <div xml:id="pressrelease" type="section">
                        <head>Press Release</head>
                        <p rend="right">
                            <hi rend="strong">Office of the Historian<lb/>Bureau of Public
                                Affairs<lb/>United States Department of State<lb/>??? ???, {($vol/*:published-year/string(), '???')[1]}</hi>
                        </p>
                        <p>This volume was compiled and edited by {
                            (
                                let $editors := $vol/*:editor[@role="primary"][. ne '']
                                let $editor-count := count($editors)
                                let $first-editors := subsequence($editors, 1, $editor-count - 1)
                                let $last-editor := $editors[last()]
                                return
                                    string-join(
                                        (
                                            string-join(
                                                $first-editors,
                                                ", "
                                            ),
                                            $last-editor
                                        ),
                                        ", and "
                                    )
                                ,
                                '???'
                            )[1]
                            }. The volume and this
                            press release are available on the Office of the Historian website at <ref
                                target="https://history.state.gov/historicaldocuments/{$vol/@id}"
                                >https://history.state.gov/historicaldocuments/{$vol/@id/string()}</ref>. Copies
                            of the volume will be available for purchase from the U.S. Government Publishing
                            Office online at <ref target="http://bookstore.gpo.gov"
                                >http://bookstore.gpo.gov</ref> (GPO S/N ???; ISBN {(normalize-space($vol/*:isbn13), '???')[1]}), or by calling
                            toll-free 1-866-512-1800 (D.C. area 202-512-1800). For further information,
                            contact <ref target="mailto:history@state.gov">history@state.gov</ref>. </p>
                    </div>
                    <!--<div xml:id="preface" type="section"/>
                        <div xml:id="sources" type="section"/>
                        <div xml:id="terms" type="section"/>
                        <div xml:id="persons" type="section"/>-->
                </front>
                <body/>
                <back/>
            </text>
        </TEI>
    return
        try {
            if (count($shell-files) gt 1) then
                let $zip-filename := 'frus-shell-files-' || format-date(current-date(), '[Y]-[M01]-[D01]') || '.zip'
                let $entries :=
                    for $shell-file in $shell-files
                    let $filename := $shell-file/@xml:id || '.xml'
                    return
                        <entry name="{$filename}" type="xml">{$shell-file}</entry>
                return
                    (
                    response:set-header("Content-Disposition", concat("attachment; filename=", $zip-filename))
                    ,
                    response:stream-binary(compression:zip($entries, false()), 'application/zip', $zip-filename)
                    ,
                    <p class="bg-success text-success">{ count($shell-files) } shell files included in { $zip-filename }.</p>
                    )
            else
                let $filename := $shell-files/@xml:id || '.xml'
                let $serialization-parameters :=
                    <output:serialization-parameters>
                        <output:method>xml</output:method>
                        <output:indent>yes</output:indent>
                    </output:serialization-parameters>
                return
                    (
                    response:set-header("Content-Disposition", concat("attachment; filename=", $filename))
                    ,
                    response:stream($shell-files, "method=xml indent=yes")
                    ,
                    <p class="bg-success text-success">Generated shell file for { $filename }.</p>
                    )
            ,
            string-join($shell-files/@xml:id ! (. || '.xml'), '; ')
        } catch * {
            <p class="bg-danger">There was an unexpected problem. {concat($err:code, ": ", $err:description, ' (', $err:module, ' ', $err:line-number, ':', $err:column-number, ')')}</p>
        }
};

declare function local:form($volumes as xs:string*) {
    <form action="{request:get-url()}">
        <div class="form-group">
            <label for="volumes" class="control-label">Volume IDs</label>
            <div>
                <textarea name="volumes" id="volumes" class="form-control" rows="6">{$volumes}</textarea>
            </div>
        </div>
        <div class="form-group">
            <button type="submit" class="btn btn-default">Generate Shell Files</button>
            <a class="btn btn-default" href="{request:get-url()}" role="button">Clear</a>
        </div>
    </form>
};

declare function local:validate($vol-ids as xs:string*) {
    for $vol-id in $vol-ids
    return
        if (collection('/db/apps/frus/bibliography')/volume[@id = $vol-ids]) then ()
        else $vol-id
};

let $titles := ('Release', 'Shell File Helper')
let $new-volumes := request:get-parameter('volumes', ())
let $body :=
    <div>
        <h2>{$titles[2]}</h2>
        {
            if ($new-volumes) then
                (
                local:form($new-volumes)
                ,
                let $vol-ids :=
                    for $vol-id in tokenize($new-volumes, '\s+')[. ne '']
                    order by $vol-id
                    return $vol-id
                let $invalid-ids := local:validate($vol-ids)
                return
                    if (empty($invalid-ids)) then
                        <div>
                            <h2>Results</h2>
                            {local:generate-shell($vol-ids)}
                        </div>
                    else
                        <div class="bg-danger">
                            <p>The following volume ID(s) are invalid. Please correct the following and resubmit.</p>
                            <ul>{
                                for $vol-id in $invalid-ids
                                return
                                    <li>{$vol-id}</li>
                            }</ul>
                        </div>
                )
            else
                (
                local:form(()),
                <p>Please enter volume IDs, one per line. (Click <a href="?volumes=frus1989-92v01">here</a> to try generating a shell file for frus1989-92v01.)
                If you enter a single volume ID, a single XML file will download; if you enter multiple, the files will be compressed and downloaded as a .zip file.</p>
                )
        }
    </div>
return
    release:wrap-html($titles, $body)
