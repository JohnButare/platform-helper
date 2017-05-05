<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- 
	Convert XML input to XML, useful for a NULL XML transform to display the incoming XML when an XSL transform is required.
--> 
	<xsl:output indent="yes" omit-xml-declaration="yes" method="xml" encoding="UTF-8" media-type="application/xml"/>
	
	<!-- ignore whitespace -->
  <xsl:template match="text()[preceding-sibling::node() or following-sibling::node()]"/>
	
	<xsl:template match="/">
<xsl:text  disable-output-escaping="yes">&lt;?xml version="1.0" encoding="UTF-8"?&gt;&#xA;</xsl:text>
<xsl:apply-templates select="child::node()" />
	</xsl:template>
	
  <xsl:template match="*" name="base">
		
		<!--  opening tag - start -->
		<xsl:call-template name="indent"/>
		<xsl:text disable-output-escaping="yes">&lt;</xsl:text>
	  <xsl:value-of select="name()" />
			
    <!-- attributes -->
    <xsl:call-template name="attributes">
      <xsl:with-param name="attributes" select="../@*"/>
    </xsl:call-template>
   		
		<!-- opening tag end -->
		<xsl:text disable-output-escaping="yes">&gt;</xsl:text>	
		<xsl:if test="count(*) != 0"><xsl:text>&#xA;</xsl:text></xsl:if>
		
    <xsl:apply-templates select="child::node()"/>
		
		<!-- closing tag -->
		<xsl:if test="count(*) != 0">
			<xsl:call-template name="indent"/>
		</xsl:if>
		<xsl:text disable-output-escaping="yes">&lt;/</xsl:text>
		<xsl:value-of select="name()" />	
		<xsl:text disable-output-escaping="yes">&gt;&#xA;</xsl:text>	
    
  </xsl:template>

	<!-- Attributes -->
	<xsl:template name="attributes">
    <xsl:if test="not(count(attribute::*)=0)">
      <xsl:text> </xsl:text>
      <xsl:for-each select="attribute::*">
        <xsl:value-of select="local-name()"/>
        <xsl:text>="</xsl:text>
        <xsl:value-of select="."/>
        <xsl:text>"</xsl:text>
        <xsl:if test="not(position()=last() or last()=1)">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

	<!-- Indent -->
	<xsl:template name="indent">
    <xsl:for-each select="ancestor::*">
			<xsl:text>  </xsl:text>
    </xsl:for-each>
  </xsl:template>

	<!-- comments -->
 	<xsl:template match="comment()">
		<xsl:call-template name="indent" />
		<xsl:text disable-output-escaping="yes">&lt;!--</xsl:text>
		<xsl:value-of select="."/>
		<xsl:text disable-output-escaping="yes">--&gt;&#xA;</xsl:text>
	</xsl:template>
	 
</xsl:stylesheet>