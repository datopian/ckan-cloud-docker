#!/bin/bash
cat <<EOF > /usr/lib/ckan/venv/src/ckan/ckan/public/base/less/custom.less
@layoutLinkColor: $CKAN_PRIMARY_COLOR;
@footerTextColor: mix(#FFF, @layoutLinkColor, 60%);
@footerLinkColor: @footerTextColor;
@mastheadBackgroundColor: @layoutLinkColor;
@btnPrimaryBackground: lighten(@layoutLinkColor, 10%);
@btnPrimaryBackgroundHighlight: @layoutLinkColor;
EOF
lessc /usr/lib/ckan/venv/src/ckan/ckan/public/base/less/main.less /var/lib/ckan/main.css
