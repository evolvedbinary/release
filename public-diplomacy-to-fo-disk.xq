xquery version "3.0";

import module namespace t2f="http://history.state.gov/ns/xquery/tei2fo" at "/db/apps/release/modules/tei2fo.xq";

let $vol-path := '/db/apps/public-diplomacy/public-diplomacy.xml'
let $div-id := request:get-parameter('div-id', ())
let $output-type := request:get-parameter('output-type', '')
let $renderer := request:get-parameter('renderer', '')
let $fo := t2f:public-diplomacy-to-fo($vol-path, $div-id, $output-type, $renderer)
let $fo-filename := concat('public-diplomacy', if ($div-id) then concat('_', $div-id) else (), '.fo')
let $file-system-output-dir := '/Users/joe/workspace/hsg-project/repos/release/'
let $fo-dir := concat($file-system-output-dir, 'output/')
return
    system:as-user('admin', '', 
        let $mkdir := if (file:exists($fo-dir)) then () else file:mkdir($fo-dir)
        return
            try {
                let $attempt := 
                    file:serialize(
                        $fo,
                        <x>{concat($fo-dir, $fo-filename)}</x>,
                        'indent=no'
                        )
                return
                    <ok/>
                } 
            catch * {
                let $log-message := 
                    concat('TEI-to-FO: Error while generating pdf version of public-diplomacy: ', 
                        $err:code, $err:value, " module: ",
                        $err:module, "(", $err:line-number, ",", $err:column-number, ")"
                        )
                let $log := util:log('INFO', $log-message)
                return
                    <error>{$log-message}</error>
                }
        )