xquery version "3.0";

import module namespace frus = "http://history.state.gov/ns/xquery/frus" at "modules/frus.xql";
import module namespace release = "http://history.state.gov/ns/xquery/release" at "modules/release.xql";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function local:link($vol-id) {
    concat('https://history.state.gov/historicaldocuments/', $vol-id)
};

declare function local:join-with-and($words as xs:string+) as xs:string {
    let $count := count($words)
    return
        if ($count = 1) then
            $words
        else if ($count = 2) then
            string-join($words, ' and ')
        else
            concat(
                string-join(subsequence($words, 1, $count - 1), ', '),
                ', and ',
                $words[last()]
            )
};

declare function local:format-integer($integer as xs:integer) {
    let $numbers := ('one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen')
    let $tens := ('twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety')
    return
        if ($integer lt 20) then $numbers[$integer]
        else
            concat($tens[floor($integer div 10) - 1], if ($integer mod 10) then concat('-', $numbers[$integer mod 10]) else ())
};

declare function local:one-volume-tweet($vol-id as xs:string) {
    let $title := concat('Foreign Relations, ', string-join((frus:volume-title($vol-id, 'sub-series'), frus:volume-title($vol-id, 'volume'), replace(frus:volume-title($vol-id, 'volume-number'), 'Volume', 'Vol.')), ', '))
    let $link := local:link($vol-id)
    let $text := concat('Now available: ', $title, ' ', $link)
    return
        element tweet {
            attribute chars { string-length($text) },
            element text { $text }
        }
};

declare function local:summary-tweet($vol-ids as xs:string+) {
    let $text := concat(count($vol-ids), ' newly-digitized Foreign Relations volumes covering events ', local:coverage-date-range($vol-ids), ' now available [tumblr link] #twitterstorians')
    return
        element tweet {
            attribute chars { string-length($text) },
            element text { $text }
        }
};

declare function local:tweets($vol-ids as xs:string*) {
    <div>
        <h2>Tweets</h2>
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>#</th>
                    <th>Vol. ID</th>
                    <th>Chars</th>
                    <th>Tweet</th>
                </tr>
            </thead>
            <tbody>{
                let $summary-tweet := local:summary-tweet($vol-ids)
                return
                    <tr>
                        <td>1</td>
                        <td><i>n/a</i></td>
                        <td>{$summary-tweet/@chars/string()}</td>
                        <td>{$summary-tweet/text/string()}</td>
                    </tr>
                ,
                for $vol-id at $n in $vol-ids
                let $tweet-info := local:one-volume-tweet($vol-id)
                return
                    <tr>
                        <td>{$n + 1}</td>
                        <td>{$vol-id}</td>
                        <td>{$tweet-info/@chars/string()}</td>
                        <td>{$tweet-info/text/string()}</td>
                    </tr>
            }</tbody>
        </table>
    </div>
};

declare function local:publication-date-range($vol-ids as xs:string+) {
    let $published-years := collection('/db/apps/frus/bibliography/')/volume[@id = $vol-ids]/published-year
    let $start := min($published-years)
    let $end := max($published-years)
    return
        if ($start = $end) then
            concat('in ', $start)
        else
            concat('between ', $start, ' and ', $end)
};

declare function local:coverage-date-range($vol-ids as xs:string+) {
    let $coverage := collection('/db/apps/frus/bibliography')/volume[@id = $vol-ids]/coverage
    let $start := min($coverage)
    let $end := max($coverage)
    return
        if ($start = $end) then
            $start
        else
            concat('between ', $start, ' and ', $end)
};

declare function local:press-release($vol-ids as xs:string+) {
    let $volume-count := count($vol-ids)
    let $volume-count-english := local:format-integer($volume-count)
    let $publication-dates := local:publication-date-range($vol-ids)
    let $coverage-dates := local:coverage-date-range($vol-ids)
    let $grouping-codes := doc('/db/apps/frus/code-tables/grouping-code-table.xml')//item
    return
        <div>
            <h2>Press Release</h2>
            <p>The Department of State today announces the release of newly digitized versions of {$volume-count-english} volumes from the <em>Foreign Relations of the United States</em> series, the official documentary record of U.S. foreign relations. These volumes cover events that took place {$coverage-dates} and were originally published in print {$publication-dates}:</p>
            <div>{
                for $vols in collection('/db/apps/frus/bibliography')/volume[@id = $vol-ids]
                group by $sub-series := normalize-space($vols/title[@type='sub-series'])
                order by $vols[1]/title[@type='sub-series']/@n
                return
                    (
                    let $series-title := frus:volume-title($vols[1]/@id, 'series')
                    let $sub-series-title := frus:volume-title($vols[1]/@id, 'sub-series')
                    return
                        <p>
                            <b><i>{$series-title, if ($sub-series-title) then ',' else ()}</i> {if ($sub-series-title) then $sub-series-title else ()}</b>
                        </p>
                        ,
                    <ol>{
                        for $vol in $vols
                        let $vol-id := $vol/@id
                        let $link := local:link($vol-id)
                        let $published-year := doc(concat('/db/apps/frus/bibliography', $vol-id, '.xml'))/volume/published-year
                        let $title :=
                            string-join(
                                (frus:volume-title($vol-id, 'volume'), frus:volume-title($vol-id, 'volume-number')),
                                ', '
                                )
                        order by $vol-id
                        return
                            <li><a href="{$link}">{$title}</a><!--. Washington: U.S. Government Printing Office, {$published-year}.--></li>
                    }</ol>
                    )
            }</div>
            <p>Today’s release is part of the Office of the Historian’s ongoing project, in partnership with the University of Wisconsin Digital Collections Center, to digitize the entire <em>Foreign Relations</em> series. The University graciously provided high quality scanned images of each printed book, which the Office further digitized to create a full text searchable edition. These volumes are available online and as free ebooks at the Office of the Historian’s website (<a href="https://history.state.gov/historicaldocuments">https://history.state.gov/historicaldocuments</a>). This is the latest in a series of quarterly releases, which will continue until the <em>FRUS</em> digital archive is complete.</p>
        </div>
};

declare function local:form($volumes as xs:string*) {
    <div class="form-group">
        <form action="{request:get-url()}">
            <label for="volumes" class="control-label">Volume IDs, one per line</label>
            <div>
                <textarea name="volumes" id="volumes" class="form-control" rows="6">{$volumes}</textarea>
            </div>
            <button type="submit" class="btn btn-default">Submit</button>
            <a class="btn btn-default" href="{request:get-url()}" role="button">Clear</a>
        </form>
    </div>
};

declare function local:validate($vol-ids as xs:string*) {
    for $vol-id in $vol-ids
    return
        if (frus:exists-volume($vol-id)) then ()
        else $vol-id
};

(:
let $new-volumes := ('frus1949v01', 'frus1950v01', 'frus1949v02')
for $vol-id in $new-volumes
return
    local:generate-volume-tweet($vol-id)
:)
(:
let $login := 'wicentowskijc'
let $api-key := 'ff5345b4a45378281564d4f220ca8574'
let $short-url := 'http://go.usa.gov/bvDT'
let $output-format := 'xml'
return
    go:expand($login, $api-key, $short-url, $output-format)
:)
(:
:)
let $titles := ('Release', 'Quarterly Release Helper')
let $new-volumes := request:get-parameter('volumes', ())
let $body :=
    <div>
        <h2>{$titles[2]}</h2>
        {

            if ($new-volumes) then
                (
                local:form($new-volumes),
                let $vol-ids :=
                    for $vol-id in tokenize($new-volumes, '\s+')
                    order by $vol-id
                    return $vol-id
                let $invalid-ids := local:validate($vol-ids)
                return
                    if (empty($invalid-ids)) then
                        (
                        local:press-release($vol-ids)
                        ,
                        local:tweets($vol-ids)
                        )
                    else
                        <div class="bg-danger">
                            <p>The following volume ID(s) are invalid. Please correct the ID and resubmit.</p>
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
                <p>Please enter volume IDs, one per line. (Click <a href="?volumes=frus1949v01%0D%0Afrus1950v01%0D%0Afrus1949v02">here</a> to try.)</p>
                )
        }
    </div>
return
    release:wrap-html($titles, $body)
