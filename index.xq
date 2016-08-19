xquery version "3.0";

import module namespace release = "http://history.state.gov/ns/xquery/release" at "modules/release.xql";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function local:aws-config-installed() {
    try {
        util:import-module(xs:anyURI("http://history.state.gov/ns/xquery/aws_config"), "aws_config", xs:anyURI("/db/apps/s3/modules/aws_config.xqm")),
        true()
    } catch * {
        false()
    }
};

let $title := 'Release'
let $content :=
    <div>
        <ul>
            <li><a href="shell-file.xq">Shell File Helper</a></li>
            <li><a href="ebook-batch.xq">Ebook Batch Helper</a></li>
            <li><a href="quarterly-release.xq">Quarterly Release Helper</a></li>
            <li><a href="s3-cache.xq">S3 Cache Helper</a>
                { 
                    if (local:aws-config-installed()) then 
                        () 
                    else 
                        <span class="text-warning"> (S3 app isn't configured yet. See <a href="../s3">S3</a>.)</span>
                }
            </li>
        </ul>
    </div>
return
    release:wrap-html($title, $content)
