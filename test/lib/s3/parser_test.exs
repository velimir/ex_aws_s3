defmodule ExAws.S3.ParserTest do
  use ExUnit.Case, async: true

  test "#parse_list_objects parses CommonPrefixes" do
    list_objects_response = """
    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Name>example-bucket</Name>
      <Prefix></Prefix>
      <Marker></Marker>
      <MaxKeys>1000</MaxKeys>
      <Delimiter>/</Delimiter>
      <IsTruncated>false</IsTruncated>
      <Contents>
        <Key>sample.jpg</Key>
        <LastModified>2011-02-26T01:56:20.000Z</LastModified>
        <ETag>&quot;bf1d737a4d46a19f3bced6905cc8b902&quot;</ETag>
        <Size>142863</Size>
        <Owner>
        <ID>canonical-user-id</ID>
        </Owner>
        <StorageClass>STANDARD</StorageClass>
      </Contents>
      <CommonPrefixes>
        <Prefix>photos/</Prefix>
      </CommonPrefixes>
    </ListBucketResult>
    """

    result = ExAws.S3.Parsers.parse_list_objects({:ok, %{body: list_objects_response}})
    {:ok, %{body: %{common_prefixes: prefixes}}} = result
    prefix_list = Enum.map(prefixes, &Map.get(&1, :prefix))

    assert ["photos/"] == prefix_list
  end

  test "#parse_list_objects allows unowned objects" do
    list_objects_response = """
    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Name>example-bucket</Name>
      <Prefix></Prefix>
      <Marker></Marker>
      <MaxKeys>1000</MaxKeys>
      <Delimiter>/</Delimiter>
      <IsTruncated>false</IsTruncated>
      <Contents>
        <Key>sample.jpg</Key>
        <LastModified>2011-02-26T01:56:20.000Z</LastModified>
        <ETag>&quot;bf1d737a4d46a19f3bced6905cc8b902&quot;</ETag>
        <Size>142863</Size>
        <StorageClass>STANDARD</StorageClass>
      </Contents>
      <CommonPrefixes>
        <Prefix>photos/</Prefix>
      </CommonPrefixes>
    </ListBucketResult>
    """

    result = ExAws.S3.Parsers.parse_list_objects({:ok, %{body: list_objects_response}})
    {:ok, _} = result
  end

  test "#initiate_multipart_upload parses response" do
    initiate_multipart_upload_response = """
    <InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Bucket>somebucket</Bucket>
      <Key>abcd</Key>
      <UploadId>bUCMhxUCGCA0GiTAhTj6cq2rChItfIMYBgO7To9yiuUyDk4CWqhtHPx8cGkgjzyavE2aW6HvhQgu9pvDB3.oX73RC7N3zM9dSU3mecTndVRHQLJCAsySsT6lXRd2Id2a</UploadId>
    </InitiateMultipartUploadResult>
    """

    result =
      ExAws.S3.Parsers.parse_initiate_multipart_upload(
        {:ok, %{body: initiate_multipart_upload_response}}
      )

    {:ok, %{body: %{bucket: bucket, key: key, upload_id: upload_id}}} = result

    assert "somebucket" == bucket
    assert "abcd" == key

    assert "bUCMhxUCGCA0GiTAhTj6cq2rChItfIMYBgO7To9yiuUyDk4CWqhtHPx8cGkgjzyavE2aW6HvhQgu9pvDB3.oX73RC7N3zM9dSU3mecTndVRHQLJCAsySsT6lXRd2Id2a" ==
             upload_id
  end

  test "#parse_list_parts parses empty parts list" do
    response = ~S"""
    <?xml version="1.0" encoding="UTF-8"?>
    <ListPartsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Bucket>name_of_my_bucket</Bucket>
      <Key>name_of_my_key.ext</Key>
      <UploadId>e3gloTamzXlqzgRfKIXrFBhnxCfM35jhktoh.wduDUJHy61R_hjglrx_rLguDGxmOvPeDfzJEK7mxgx7eRwPs9XbYXVmDywrRjbJSmqr.McfkCRDjuI4cdB72IYzfFJl</UploadId>
      <Initiator>
        <ID>arn:aws:iam::123456789012:user/username</ID>
      </Initiator>
      <Owner>
        <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
      </Owner>
      <StorageClass>STANDARD</StorageClass>
      <PartNumberMarker>0</PartNumberMarker>
      <NextPartNumberMarker>0</NextPartNumberMarker>
      <MaxParts>1000</MaxParts>
      <IsTruncated>false</IsTruncated>
    </ListPartsResult>
    """

    assert {:ok, %{body: body}} = ExAws.S3.Parsers.parse_list_parts({:ok, %{body: response}})
    assert body == %{parts: []}
  end

  test "#parse_list_parts parses parts of the multipart upload" do
    response = ~S"""
    <?xml version="1.0" encoding="UTF-8"?>
    <ListPartsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Bucket>name_of_my_bucket</Bucket>
      <Key>name_of_my_key.ext</Key>
      <UploadId>e3gloTamzXlqzgRfKIXrFBhnxCfM35jhktoh.wduDUJHy61R_hjglrx_rLguDGxmOvPeDfzJEK7mxgx7eRwPs9XbYXVmDywrRjbJSmqr.McfkCRDjuI4cdB72IYzfFJl</UploadId>
      <Initiator>
        <ID>arn:aws:iam::123456789012:user/username</ID>
      </Initiator>
      <Owner>
        <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
      </Owner>
      <StorageClass>STANDARD</StorageClass>
      <PartNumberMarker>0</PartNumberMarker>
      <NextPartNumberMarker>2</NextPartNumberMarker>
      <MaxParts>1000</MaxParts>
      <IsTruncated>false</IsTruncated>
      <Part>
        <PartNumber>1</PartNumber>
        <LastModified>2021-12-10T18:43:58.000Z</LastModified>
        <ETag>&quot;d53f6b1e2a3b54515f8dbcbcbe3aef9e&quot;</ETag>
        <Size>10000000</Size>
      </Part>
      <Part>
        <PartNumber>2</PartNumber>
        <LastModified>2021-12-10T18:43:47.000Z</LastModified>
        <ETag>&quot;d1cae2efbf9bfdec76ef78e5c2dd41e5&quot;</ETag>
        <Size>3811508</Size>
      </Part>
    </ListPartsResult>
    """

    assert {:ok, %{body: body}} = ExAws.S3.Parsers.parse_list_parts({:ok, %{body: response}})

    assert body == %{
             parts: [
               %{
                 part_number: "1",
                 etag: ~s("d53f6b1e2a3b54515f8dbcbcbe3aef9e"),
                 size: "10000000"
               },
               %{
                 part_number: "2",
                 etag: ~s("d1cae2efbf9bfdec76ef78e5c2dd41e5"),
                 size: "3811508"
               }
             ]
           }
  end

  test "#parse_object_tagging parses empty tagset" do
    response = ~S"""
    <?xml version="1.0" encoding="UTF-8"?>
    <Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <TagSet/>
    </Tagging>
    """

    assert {:ok, %{body: body}} = ExAws.S3.Parsers.parse_object_tagging({:ok, %{body: response}})
    assert body == %{tags: []}
  end

  test "#parse_object_tagging parses tags" do
    response = ~S"""
    <?xml version="1.0" encoding="UTF-8"?>
    <Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <TagSet>
        <Tag>
          <Key>tag1</Key>
          <Value>val1</Value>
        </Tag>
        <Tag>
          <Key>tag2</Key>
          <Value>val2</Value>
        </Tag>
      </TagSet>
    </Tagging>
    """

    assert {:ok, %{body: body}} = ExAws.S3.Parsers.parse_object_tagging({:ok, %{body: response}})
    assert body == %{tags: [%{key: "tag1", value: "val1"}, %{key: "tag2", value: "val2"}]}
  end

  test "#parse_object_versions parses ListVersionsResult" do
    response = ~S"""
    <ListVersionsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01">
    <Name>bucket</Name>
    <Prefix>my</Prefix>
    <KeyMarker/>
    <VersionIdMarker/>
    <MaxKeys>5</MaxKeys>
    <IsTruncated>false</IsTruncated>
    <Version>
        <Key>my-image.jpg</Key>
        <VersionId>3/L4kqtJl40Nr8X8gdRQBpUMLUo</VersionId>
        <IsLatest>true</IsLatest>
         <LastModified>2009-10-12T17:50:30.000Z</LastModified>
        <ETag>&quot;fba9dede5f27731c9771645a39863328&quot;</ETag>
        <Size>434234</Size>
        <StorageClass>STANDARD</StorageClass>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
        </Owner>
    </Version>
    <DeleteMarker>
        <Key>my-second-image.jpg</Key>
        <VersionId>03jpff543dhffds434rfdsFDN943fdsFkdmqnh892</VersionId>
        <IsLatest>true</IsLatest>
        <LastModified>2009-11-12T17:50:30.000Z</LastModified>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
        </Owner>
    </DeleteMarker>
    <Version>
        <Key>my-second-image.jpg</Key>
        <VersionId>QUpfdndhfd8438MNFDN93jdnJFkdmqnh893</VersionId>
        <IsLatest>false</IsLatest>
        <LastModified>2009-10-10T17:50:30.000Z</LastModified>
        <ETag>&quot;9b2cf535f27731c974343645a3985328&quot;</ETag>
        <Size>166434</Size>
        <StorageClass>STANDARD</StorageClass>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
        </Owner>
    </Version>
    <DeleteMarker>
        <Key>my-third-image.jpg</Key>
        <VersionId>03jpff543dhffds434rfdsFDN943fdsFkdmqnh892</VersionId>
        <IsLatest>true</IsLatest>
        <LastModified>2009-10-15T17:50:30.000Z</LastModified>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
        </Owner>
    </DeleteMarker>
    <Version>
        <Key>my-third-image.jpg</Key>
        <VersionId>UIORUnfndfhnw89493jJFJ</VersionId>
        <IsLatest>false</IsLatest>
        <LastModified>2009-10-11T12:50:30.000Z</LastModified>
        <ETag>&quot;772cf535f27731c974343645a3985328&quot;</ETag>
        <Size>64</Size>
        <StorageClass>STANDARD</StorageClass>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
        </Owner>
     </Version>
    </ListVersionsResult>
    """

    assert {:ok, %{body: body}} =
             ExAws.S3.Parsers.parse_object_versions({:ok, %{body: response}})

    %{
      name: name,
      prefix: prefix,
      max_keys: max_keys,
      versions: versions,
      delete_markers: delete_markers
    } = body

    assert name == "bucket"
    assert prefix == "my"
    assert max_keys == "5"

    assert is_list(versions)
    assert is_list(delete_markers)
    assert Enum.count(versions) == 3
    assert Enum.count(delete_markers) == 2

    owner = %{id: "75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a"}

    assert Enum.at(versions, 0) == %{
             key: "my-image.jpg",
             version_id: "3/L4kqtJl40Nr8X8gdRQBpUMLUo",
             etag: "\"fba9dede5f27731c9771645a39863328\"",
             is_latest: "true",
             last_modified: "2009-10-12T17:50:30.000Z",
             size: "434234",
             owner: owner
           }

    assert Enum.at(delete_markers, 0) == %{
             key: "my-second-image.jpg",
             version_id: "03jpff543dhffds434rfdsFDN943fdsFkdmqnh892",
             is_latest: "true",
             last_modified: "2009-11-12T17:50:30.000Z",
             owner: owner
           }

    assert Enum.map(versions, & &1.key) ==
             ["my-image.jpg", "my-second-image.jpg", "my-third-image.jpg"]

    assert Enum.map(delete_markers, & &1.key) == ["my-second-image.jpg", "my-third-image.jpg"]
  end

  describe "#parse_object_versions" do
    defp parse_versions(entries) do
      xml =
        ~s(<?xml version="1.0" encoding="UTF-8"?>) <>
          ~s(<ListVersionsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">) <>
          "<Name>bucket</Name>#{entries}</ListVersionsResult>"

      {:ok, %{body: body}} = ExAws.S3.Parsers.parse_object_versions({:ok, %{body: xml}})
      body
    end

    test "returns empty strings for missing fields and empty lists for missing entries" do
      assert parse_versions("") == %{
               name: "bucket",
               prefix: "",
               max_keys: "",
               key_marker: "",
               next_key_marker: "",
               version_id_marker: "",
               next_version_id_marker: "",
               is_truncated: "",
               versions: [],
               delete_markers: []
             }

      assert %{versions: [%{key: "", size: "", owner: %{id: ""}}]} =
               parse_versions("<Version><Key/><Owner></Owner></Version>")
    end

    test "returns a nil owner when an entry has no Owner" do
      assert %{
               versions: [%{key: "a", owner: nil}],
               delete_markers: [%{key: "b", owner: nil}]
             } =
               parse_versions(
                 "<Version><Key>a</Key></Version><DeleteMarker><Key>b</Key></DeleteMarker>"
               )
    end

    test "decodes entities, character references and CDATA" do
      assert %{versions: [%{key: key, etag: etag, size: size}]} =
               parse_versions(
                 "<Version><Key>a&amp;b&lt;&gt;&apos; x&#13;y &#x4e2d;ü</Key>" <>
                   "<ETag>&quot;abc&quot;</ETag><Size><![CDATA[12]]></Size></Version>"
               )

      assert key == "a&b<>' x\ry 中ü"
      assert etag == "\"abc\""
      assert size == "12"
    end

    # String cases from the restXml protocol tests that AWS SDKs implement:
    # https://github.com/smithy-lang/smithy/blob/main/smithy-aws-protocol-tests/model/restXml/document-structs.smithy
    for {id, xml, expected} <- [
          {"SimpleScalarPropertiesComplexEscapes", "escaped data: &amp;lt;&#xD;&#10;",
           "escaped data: &lt;\r\n"},
          {"SimpleScalarPropertiesWithEscapedCharacter", "&lt;string&gt;", "<string>"},
          {"SimpleScalarPropertiesWithWhiteSpace", " string with white    space ",
           " string with white    space "},
          {"SimpleScalarPropertiesPureWhiteSpace", "  ", "  "},
          {"XmlEmptySelfClosedStrings", nil, ""}
        ] do
      test "decodes a key like the #{id} protocol test" do
        key = if unquote(xml), do: "<Key>#{unquote(xml)}</Key>", else: "<Key/>"

        assert %{versions: [%{key: unquote(expected)}]} =
                 parse_versions("<Version>#{key}</Version>")
      end
    end

    test "ignores the XML declaration, comments and CDATA outside fields like SimpleScalarPropertiesWithXMLPreamble" do
      xml = """
      <?xml version = "1.0" encoding = "UTF-8"?>
      <ListVersionsResult>
          <![CDATA[characters representing CDATA]]>
          <Name>bucket</Name>
          <!--xml comment-->
      </ListVersionsResult>
      """

      assert {:ok, %{body: %{name: "bucket", versions: []}}} = parse_xml(xml)
    end

    test "keeps whitespace inside values" do
      assert %{versions: [%{key: " a b "}, %{key: " \t\n "}]} =
               parse_versions(
                 "<Version><Key> a b </Key></Version><Version><Key> \t\n </Key></Version>"
               )
    end

    test "reads only the fields of the entry and of its first Owner" do
      assert %{versions: [%{key: "k", owner: %{id: "o"}}]} =
               parse_versions(
                 "<Version><Key>k</Key><ChecksumAlgorithm>CRC32</ChecksumAlgorithm>" <>
                   "<RestoreStatus><Key>no</Key><ID>no</ID></RestoreStatus>" <>
                   "<Owner><ID>o</ID><DisplayName>d</DisplayName></Owner>" <>
                   "<Owner><ID>no</ID></Owner></Version>"
               )

      assert %{delete_markers: [%{key: "k"} = delete_marker]} =
               parse_versions("<DeleteMarker><Key>k</Key><Size>1</Size></DeleteMarker>")

      refute Map.has_key?(delete_marker, :size)
    end

    test "ignores prefixed elements" do
      assert %{name: "bucket", versions: [%{key: "k"}]} =
               parse_versions(
                 ~s(<x:Name xmlns:x="urn:x">no</x:Name>) <>
                   ~s(<Version><x:Key xmlns:x="urn:x">no</x:Key><Key>k</Key></Version>)
               )
    end

    test "exits on entity declarations" do
      for declaration <- [
            ~s(<!ENTITY a "b">),
            ~s(<!ENTITY % a "b">),
            ~s(<!ENTITY a SYSTEM "#{__ENV__.file}">),
            ~s(<!NOTATION n SYSTEM "n"><!ENTITY a SYSTEM "a" NDATA n>)
          ] do
        xml =
          "<!DOCTYPE ListVersionsResult [#{declaration}]>" <>
            "<ListVersionsResult><Name>b</Name></ListVersionsResult>"

        assert {:fatal, {:entities_not_allowed, _}} = catch_exit(parse_xml(xml))
      end
    end

    test "exits on malformed XML" do
      assert {:fatal, _} = catch_exit(parse_xml("<ListVersionsResult><Name>b</Name><Version>"))
      assert {:fatal, _} = catch_exit(parse_xml("<html>Service Unavailable"))

      assert {:fatal, _} =
               catch_exit(parse_xml("<ListVersionsResult><Name>&b;</Name></ListVersionsResult>"))
    end

    test "accepts comments and processing instructions after the root" do
      assert {:ok, %{body: %{name: "b"}}} =
               parse_xml(
                 "<ListVersionsResult><Name>b</Name></ListVersionsResult><!-- c --><?p?>\n"
               )
    end

    test "exits on an external DTD before it reads it" do
      for doctype <- [~s(SYSTEM "#{__ENV__.file}"), ~s(PUBLIC "-//X//Y" "#{__ENV__.file}")] do
        xml =
          "<!DOCTYPE ListVersionsResult #{doctype}>" <>
            "<ListVersionsResult><Name>b</Name></ListVersionsResult>"

        assert {:fatal, {:external_dtd_not_allowed, _}} = catch_exit(parse_xml(xml))
      end

      assert {:ok, %{body: %{name: "b"}}} =
               parse_xml(
                 "<!DOCTYPE ListVersionsResult><ListVersionsResult><Name>b</Name></ListVersionsResult>"
               )
    end

    test "exits on another root element" do
      assert {:fatal, _} = catch_exit(parse_xml("<Error><Name>b</Name></Error>"))

      assert {:fatal, _} =
               catch_exit(parse_xml(~s(<s3:ListVersionsResult xmlns:s3="urn:x"/>)))
    end

    defp parse_xml(xml), do: ExAws.S3.Parsers.parse_object_versions({:ok, %{body: xml}})

    test "passes errors through" do
      assert ExAws.S3.Parsers.parse_object_versions({:error, :timeout}) == {:error, :timeout}
    end
  end

  describe "#parse_upload_part_copy" do
    test "parses a good response" do
      parse_upload_part_copy_response = """
      <CopyPartResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <LastModified>2019-02-09T06:27:26.000Z</LastModified>
      <ETag>&quot;7cbef1ad67ecd0d9ba35af98d3de5a94&quot;</ETag>
      </CopyPartResult>
      """

      result =
        ExAws.S3.Parsers.parse_upload_part_copy({:ok, %{body: parse_upload_part_copy_response}})

      assert {:ok, %{body: %{last_modified: last_modified, etag: etag}}} = result
      assert "2019-02-09T06:27:26.000Z" == last_modified
      assert "\"7cbef1ad67ecd0d9ba35af98d3de5a94\"" == etag
    end

    test "handles nil" do
      result = ExAws.S3.Parsers.parse_upload_part_copy({:ok, %{body: nil}})
      assert {:error, %{body: nil}} == result
    end

    test "handles errors by passing them through" do
      error = {:error, "error"}
      result = ExAws.S3.Parsers.parse_upload_part_copy(error)
      assert result == error
    end
  end

  describe "#parse_complete_multipart_upload" do
    test "parses CompleteMultipartUploadResult" do
      complete_multipart_upload_response = """
      <CompleteMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <Location>https://s3-eu-west-1.amazonaws.com/my-bucket/tmp-copy3.mp4</Location>
        <Bucket>my-bucket</Bucket>
        <Key>tmp-copy3.mp4</Key>
        <ETag>&quot;17fbc0a106abbb6f381aac6e331f2a19-1&quot;</ETag>
      </CompleteMultipartUploadResult>
      """

      result =
        ExAws.S3.Parsers.parse_complete_multipart_upload(
          {:ok, %{body: complete_multipart_upload_response}}
        )

      {:ok, %{body: body}} = result

      assert body == %{
               location: "https://s3-eu-west-1.amazonaws.com/my-bucket/tmp-copy3.mp4",
               bucket: "my-bucket",
               key: "tmp-copy3.mp4",
               etag: "\"17fbc0a106abbb6f381aac6e331f2a19-1\""
             }
    end

    test "handles errors by passing them through" do
      error = {:error, "error"}
      result = ExAws.S3.Parsers.parse_complete_multipart_upload(error)
      assert result == error
    end
  end
end
