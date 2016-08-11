xquery version "3.1";

module namespace release="http://history.state.gov/ns/xquery/release";

declare variable $release:app-url := '/exist/apps/release';

declare function release:wrap-html($titles as xs:string+, $content as element()+) {
    <html>
        <head>
            <title>{string-join(reverse($titles), ' | ')}</title>
            <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" rel="stylesheet"/>
            <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"></script>
            <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
            <link rel="stylesheet" href="{$release:app-url}/resources/css/print.css"/>
        </head>
        <body>
            <div class="container">
                <h1><a href="{$release:app-url}">{$titles[1]}</a></h1>
                {$content}
            </div>
        </body>
    </html>
};
