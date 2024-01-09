#!/bin/bash

# Define the paths to the build.gradle and pom.xml files  
BUILD_GRADLE_PATH="${BUILD_GRADLE_PATH}"
POM_XML_PATH="${POM_XML_PATH}"

echo "Extracting dependencies from build.gradle"  
# Extract the dependencies from the build.gradle file  
# DEPENDENCIES=$(awk '/dependencies {/,/}/{print}' $BUILD_GRADLE_PATH | grep 'implementation' | awk -F"'" '{print $2}')
DEPENDENCIES=$(awk '/dependencies {/,/}/{print}' $BUILD_GRADLE_PATH | sed "s/\"/'/g" | grep 'implementation' | grep -v '^ *//' | awk -F"'" '{print $2}')
echo -e "Dependencies: \n$DEPENDENCIES"

# Start the dependencies section for the pom.xml file  
POM_DEPENDENCIES="<dependencies>  
        <dependency>  
          <groupId>junit</groupId>  
          <artifactId>junit</artifactId>  
          <version>2.0.0</version>  
          <type>jar</type>  
          <scope>test</scope>  
          <optional>true</optional>  
        </dependency>
        <!-- Added dependencies -->"

echo -e "\nTransforming dependencies to Maven format"  
# Loop over the dependencies and add them to the pom.xml dependencies section  
for DEPENDENCY in $DEPENDENCIES; do  
    echo "Dependency: $DEPENDENCY"  
    IFS=':' read -ra ADDR <<< "$DEPENDENCY"  
    # Only add the dependency if it is split into three parts
    if [ ${#ADDR[@]} -eq 3 ]; then
        # Handle dependencies with a variable for the version number  
        if [[ ${ADDR[2]} == \$* ]]; then  
            VERSION_VAR=${ADDR[2]#\$}  
            VERSION=$(awk -v var="$VERSION_VAR" '/def/ { if ($2 == var) version=$4 } END { print version }' $BUILD_GRADLE_PATH | sed 's/"//g')
            ADDR[2]=$VERSION  
        fi  
        POM_DEPENDENCIES+="  
        <dependency>  
            <groupId>${ADDR[0]}</groupId>  
            <artifactId>${ADDR[1]}</artifactId>  
            <version>${ADDR[2]}</version>  
        </dependency>"  
    fi
done

# End the dependencies section for the pom.xml file  
POM_DEPENDENCIES+="\n</dependencies>"  
echo "POM Dependencies: $POM_DEPENDENCIES"

# Create a temporary file  
TEMP_FILE="test.txt"

echo "Writing new dependencies to temporary file"  
# Write the new dependencies section to the temporary file  
echo -e "$POM_DEPENDENCIES" > $TEMP_FILE

echo -e "Replacing dependencies in pom.xml\n"  
# Check if the dependencies section exists in the pom.xml file
if grep -q "<dependencies>" $POM_XML_PATH; then
    # Replace the dependencies section in the pom.xml file with the contents of the temporary file  
    sed -i '' "/<dependencies>/,/<\/dependencies>/{  
        /<dependencies>/r "$TEMP_FILE"
        /<dependencies>/,//d  
    }" $POM_XML_PATH
else
    # Add the dependencies section to the pom.xml file before the closing </project> tag
    sed -i '' "/<\/project>/ {  
        r "$TEMP_FILE"
        d  
    }" $POM_XML_PATH
    # add project tag
    # Check if the </project> tag exists in the pom.xml file
    if ! grep -q "</project>" $POM_XML_PATH; then
        # Add the </project> tag to the end of the pom.xml file
        echo "</project>" >> $POM_XML_PATH
    fi
fi

echo "Formatting pom.xml"
xmllint --format --output $POM_XML_PATH $POM_XML_PATH

echo "Removing temporary file"  
# Remove the temporary file  
# rm $TEMP_FILE

echo "Done"