package test.deploy.jenkins_sornar.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;
import test.deploy.jenkins_sornar.entity.Board;

import java.time.LocalDateTime;

@Getter
@Builder
@Schema(description = "게시글 응답 DTO")
public class BoardResponse {
    @Schema(description = "게시글 ID")
    private Long id;
    @Schema(description = "게시글 제목")
    private String title;
    @Schema(description = "게시글 내용")
    private String content;
    @Schema(description = "작성자")
    private String author;
    @Schema(description = "생성 일시")
    private LocalDateTime createdAt;
    @Schema(description = "수정 일시")
    private LocalDateTime updatedAt;

    public static BoardResponse from(Board board) {
        return BoardResponse.builder()
                .id(board.getId())
                .title(board.getTitle())
                .content(board.getContent())
                .author(board.getAuthor())
                .createdAt(board.getCreatedAt())
                .updatedAt(board.getUpdatedAt())
                .build();
    }
}