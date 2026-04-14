package test.deploy.jenkins_sornar.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;

@Getter
@Schema(description = "게시글 생성 요청 DTO")
public class BoardCreateRequest {

    @NotBlank
    @Size(max = 200)
    @Schema(description = "게시글 제목", example = "새로운 게시글입니다.")
    private String title;

    @NotBlank
    @Schema(description = "게시글 내용", example = "게시글의 본문 내용입니다.")
    private String content;

    @NotBlank
    @Size(max = 50)
    @Schema(description = "작성자", example = "홍길동")
    private String author;
}