#include <stdio.h>
#include <curl/curl.h>

int verify_file_transfer(const char *url)
{
    CURLcode result = curl_global_init(CURL_GLOBAL_ALL);
    if (result != CURLE_OK) {
        return result;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        curl_global_cleanup();
        return CURLE_FAILED_INIT;
    }
    result = curl_easy_setopt(curl, CURLOPT_URL, url);
    if (result == CURLE_OK) {
        result = curl_easy_setopt(curl, CURLOPT_WRITEDATA, stdout);
    }
    if (result == CURLE_OK) {
        result = curl_easy_perform(curl);
    }
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return result;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        return 2;
    }
    return verify_file_transfer(argv[1]);
}
