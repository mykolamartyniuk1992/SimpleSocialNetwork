import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef, MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { ImageCropperComponent, ImageCroppedEvent } from 'ngx-image-cropper';

export interface PhotoCropDialogData {
  event: Event;
}

@Component({
  selector: 'app-photo-crop-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    ImageCropperComponent
  ],
  templateUrl: './photo-crop-dialog.html',
  styleUrl: './photo-crop-dialog.css',
})
export class PhotoCropDialog {
  croppedImage: string = '';

  constructor(
    public dialogRef: MatDialogRef<PhotoCropDialog>,
    @Inject(MAT_DIALOG_DATA) public data: PhotoCropDialogData
  ) {}

  imageCropped(event: ImageCroppedEvent) {
    if (event.blob) {
      // Convert blob to base64
      const reader = new FileReader();
      reader.readAsDataURL(event.blob);
      reader.onloadend = () => {
        this.croppedImage = reader.result as string;
      };
    }
  }

  onCancel(): void {
    this.dialogRef.close();
  }

  onSave(): void {
    this.dialogRef.close(this.croppedImage);
  }
}
