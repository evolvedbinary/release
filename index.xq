xquery version "3.0";

import module namespace release = "http://history.state.gov/ns/xquery/release" at "modules/release.xql";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

let $title := 'Release'
let $content :=
    <div>
        <ul>
            <li><a href="quarterly-release.xq">Quarterly release helper</a></li>
        </ul>
    </div>
return
    release:wrap-html($title, $content)
