xquery version "3.1";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: the target collection into which the app is deployed :)
declare variable $target external;

xmldb:create-collection($target, 'epub-cache'),
sm:chown(xs:anyURI($target || "/ebook-batch.xq"), "admin"),
sm:chmod(xs:anyURI($target || "/ebook-batch.xq"), "rwsr-xr-x"),
sm:chown(xs:anyURI($target || "/public-diplomacy-to-fo-disk.xq"), "admin"),
sm:chmod(xs:anyURI($target || "/public-diplomacy-to-fo-disk.xq"), "rwsr-xr-x"),
sm:chown(xs:anyURI($target || "/s3-cache.xq"), "admin"),
sm:chmod(xs:anyURI($target || "/s3-cache.xq"), "rwsr-xr-x")